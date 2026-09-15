#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Containers.FileBind.Provisioner.CoreTest do
  @moduledoc """
  Tests for the file bind provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableFileBinds
  alias Edgehog.Astarte.Device.AvailableFileBinds.FileBindStatus
  alias Edgehog.Astarte.Device.CreateBind
  alias Edgehog.Astarte.Device.FileTransferCapabilities
  alias Edgehog.Containers.Container.Deployment
  alias Edgehog.Containers.FileBind.Provisioner.Core
  alias Edgehog.Files.FileDownloadRequest.Provisioner, as: FileDownloadRequestProvisioner
  alias Edgehog.Storage

  describe "File bind provisioner Core" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      deployment = deployment_fixture(tenant: tenant, device_id: device.id)

      container =
        [tenant: tenant, file_mounts: [%{mountpoint: "/etc/app.conf", required: true}]]
        |> container_fixture()
        |> Ash.load!(:file_mounts)

      %{file_mounts: [file_mount]} = container

      # Don't start a real download request provisioner: async tests cannot
      # share the SQL sandbox connection with spawned provisioner processes.
      Mimic.stub(FileDownloadRequestProvisioner, :provision, fn _request, _tenant ->
        {:ok, self()}
      end)

      Mimic.stub(Storage, :read_presigned_url, fn _path ->
        {:ok, %{get_url: "http://example.test/download"}}
      end)

      Mimic.stub(FileTransferCapabilities, :get, fn _client, _device_id ->
        {:ok,
         %FileTransferCapabilities{
           unix_permissions: false,
           server_to_device: %{storage: [], streaming: nil, filesystem: nil},
           device_to_server: %{storage: nil, streaming: nil, filesystem: nil}
         }}
      end)

      %{
        tenant: tenant,
        device: device,
        deployment: deployment,
        container: container,
        file_mount: file_mount
      }
    end

    test "ready?/1 returns true when the state is a ready one", _context do
      assert Core.ready?(%{state: :available})
      assert Core.ready?(%{state: :unavailable})
    end

    test "ready?/1 returns false when the state is not a ready one", _context do
      refute Core.ready?(%{state: :created})
      refute Core.ready?(%{state: :sent})
    end

    test "topic/1 returns the topic on which readiness is broadcast", _context do
      assert Core.topic(%{id: "file-bind-id"}) == "ready:file_binds:file-bind-id"

      assert Core.topic("file-bind-id") == "ready:file_binds:file-bind-id"
    end

    test "subscribe_topic/1 returns the topic the provisioner subscribes to", _context do
      assert Core.subscribe_topic(%{id: "file-bind-id"}) == "file_binds:file-bind-id"

      assert Core.subscribe_topic("file-bind-id") == "file_binds:file-bind-id"
    end

    test "name/1 returns the via tuple used to register the provisioner", _context do
      assert Core.name(%{id: "file-bind-id"}) ==
               {:via, Registry,
                {Edgehog.Containers.FileBind.Provisioner.Registry, "file-bind-id"}}
    end

    test "send_to_device/2 sends the bind request for a device file target", context do
      %{tenant: tenant, device: device, deployment: deployment, file_mount: file_mount} =
        context

      container_deployment = container_deployment_fixture(tenant: tenant, device_id: device.id)
      device_file = device_file_fixture(tenant: tenant, device_id: device.id)

      file_bind =
        file_bind_fixture(
          tenant: tenant,
          container_deployment_id: container_deployment.id,
          file_mount_id: file_mount.id,
          device_file_id: device_file.id
        )

      expect(CreateBind, :send_bind, fn _client, _device_id, data ->
        assert data.id == file_bind.id
        assert data.deploymentId == deployment.id
        assert data.targetId == device_file.id
        assert data.targetType == "storage"
        assert data.mountpoint == "/etc/app.conf"

        :ok
      end)

      assert :ok == Core.send_to_device(file_bind, tenant: tenant, deployment: deployment)
    end

    test "send_to_device/2 sends the bind request for a download request target", context do
      %{tenant: tenant, device: device, deployment: deployment, file_mount: file_mount} =
        context

      container_deployment = container_deployment_fixture(tenant: tenant, device_id: device.id)

      file_request = manual_file_download_request_fixture(tenant: tenant, device_id: device.id)

      file_bind =
        file_bind_fixture(
          tenant: tenant,
          container_deployment_id: container_deployment.id,
          file_mount_id: file_mount.id,
          file_download_request_id: file_request.id
        )

      expect(CreateBind, :send_bind, fn _client, _device_id, data ->
        assert data.id == file_bind.id
        assert data.deploymentId == deployment.id
        assert data.targetId == file_request.id
        assert data.targetType == "request"
        assert data.mountpoint == "/etc/app.conf"

        :ok
      end)

      assert :ok == Core.send_to_device(file_bind, tenant: tenant, deployment: deployment)
    end

    test "send_to_device/2 creates a download request for an uploaded bind without target",
         context do
      %{tenant: tenant, device: device, deployment: deployment, container: container} = context

      %{file_mounts: [file_mount]} = container

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          [
            container: container,
            device: device,
            deployment: deployment,
            file_binds: [%{file_mount_id: file_mount.id}]
          ],
          tenant: tenant
        )
        |> Ash.create()

      [file_bind] =
        Ash.load!(container_deployment, :file_binds, tenant: tenant).file_binds

      {:ok, file_bind} =
        file_bind
        |> Ash.Changeset.for_update(:mark_as_uploaded, %{
          file_name: "app.conf",
          uncompressed_file_size_bytes: 128,
          digest: "sha256:abcd",
          encoding: ""
        })
        |> Ash.update(tenant: tenant)

      expect(CreateBind, :send_bind, fn _client, _device_id, data ->
        assert data.id == file_bind.id
        assert data.deploymentId == deployment.id
        assert data.targetType == "request"
        assert data.mountpoint == "/etc/app.conf"

        :ok
      end)

      assert :ok == Core.send_to_device(file_bind, tenant: tenant, deployment: deployment)

      # The created download request is linked to the bind
      updated = Ash.get!(Edgehog.Containers.FileBind, file_bind.id, tenant: tenant)
      assert updated.file_download_request_id != nil
    end

    test "send_to_device/2 returns an error when the file was not uploaded", context do
      %{tenant: tenant, device: device, deployment: deployment, container: container} = context

      %{file_mounts: [file_mount]} = container

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          [
            container: container,
            device: device,
            deployment: deployment,
            file_binds: [%{file_mount_id: file_mount.id}]
          ],
          tenant: tenant
        )
        |> Ash.create()

      [file_bind] =
        Ash.load!(container_deployment, :file_binds, tenant: tenant).file_binds

      refute file_bind.uploaded

      assert {:error, :file_not_uploaded} ==
               Core.send_to_device(file_bind, tenant: tenant, deployment: deployment)
    end

    test "reconcile/2 marks the bind as available when the device reports it", context do
      %{tenant: tenant, device: device} = context

      container_deployment = container_deployment_fixture(tenant: tenant, device_id: device.id)

      file_bind =
        file_bind_fixture(tenant: tenant, container_deployment_id: container_deployment.id)

      expect(AvailableFileBinds, :get, fn _client, _device_id ->
        {:ok, [%FileBindStatus{id: file_bind.id}]}
      end)

      assert {:ok, updated} = Core.reconcile(file_bind, tenant: tenant)
      assert updated.id == file_bind.id
      assert updated.state == :available
    end

    test "reconcile/2 returns :not_found when the device does not report the bind",
         context do
      %{tenant: tenant, device: device} = context

      container_deployment = container_deployment_fixture(tenant: tenant, device_id: device.id)

      file_bind =
        file_bind_fixture(tenant: tenant, container_deployment_id: container_deployment.id)

      expect(AvailableFileBinds, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(file_bind, tenant: tenant)
    end

    test "temporary_error?/1 correctly recurses on nested errors", _context do
      error = "connection refused"
      assert Core.temporary_error?({:error, error}) == Core.temporary_error?(error)

      error = %{errors: ["unknown error"]}
      assert Core.temporary_error?({:error, error}) == Core.temporary_error?(error)

      error = :other
      assert Core.temporary_error?({:error, error}) == Core.temporary_error?(error)
    end

    test "temporary_error?/1 returns true for \"connection refused\" errors", _context do
      assert Core.temporary_error?("connection refused")
    end

    test "temporary_error?/1 returns true for 5xx responses", _context do
      assert Core.temporary_error?(%Astarte.Client.APIError{
               status: Enum.random(500..599),
               response: "server error"
             })

      assert Core.temporary_error?(%Edgehog.Error.AstarteAPIError{status: Enum.random(500..599)})
    end

    test "temporary_error?/1 returns true for Edgehog.Error.DeviceOffline errors", _context do
      assert Core.temporary_error?(%Edgehog.Error.DeviceOffline{})
    end

    test "temporary_error?/1 returns false for other unspecified errors", _context do
      refute Core.temporary_error?(:other_unspecified_error)
    end
  end
end
