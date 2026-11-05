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

defmodule Edgehog.Containers.EnvFile.Provisioner.CoreTest do
  @moduledoc """
  Tests for the env file provisioner Core.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.AvailableEnvFiles
  alias Edgehog.Astarte.Device.AvailableEnvFiles.EnvFileStatus
  alias Edgehog.Astarte.Device.CreateEnvFile
  alias Edgehog.Astarte.Device.FileTransferCapabilities
  alias Edgehog.Containers.Container.Deployment
  alias Edgehog.Containers.EnvFile
  alias Edgehog.Containers.EnvFile.Provisioner.Core
  alias Edgehog.Files.FileDownloadRequest.Provisioner, as: FileDownloadRequestProvisioner
  alias Edgehog.Storage

  describe "Env file provisioner Core" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      deployment = deployment_fixture(tenant: tenant, device_id: device.id)
      container = container_fixture(tenant: tenant)

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
        container: container
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
      assert Core.topic(%{id: "env-file-id"}) == "ready:env_files:env-file-id"
      assert Core.topic("env-file-id") == "ready:env_files:env-file-id"
    end

    test "subscribe_topic/1 returns the topic the provisioner subscribes to", _context do
      assert Core.subscribe_topic(%{id: "env-file-id"}) == "env_files:env-file-id"
      assert Core.subscribe_topic("env-file-id") == "env_files:env-file-id"
    end

    test "name/1 returns the via tuple used to register the provisioner", _context do
      assert Core.name(%{id: "env-file-id"}) ==
               {:via, Registry, {Edgehog.Containers.EnvFile.Provisioner.Registry, "env-file-id"}}
    end

    test "send_to_device/2 sends the env file request for a device file target", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      container_deployment = container_deployment_fixture(tenant: tenant, device_id: device.id)
      device_file = device_file_fixture(tenant: tenant, device_id: device.id)

      {:ok, env_file} =
        EnvFile
        |> Ash.Changeset.for_create(
          :create,
          %{
            container_deployment_id: container_deployment.id,
            device_id: device.id,
            device_file_id: device_file.id
          },
          tenant: tenant
        )
        |> Ash.create()

      expect(CreateEnvFile, :send_env_file, fn _client, _device_id, data ->
        assert data.id == env_file.id
        assert data.deploymentId == deployment.id
        assert data.targetId == device_file.id
        assert data.targetType == "storage"

        :ok
      end)

      assert :ok == Core.send_to_device(env_file, tenant: tenant, deployment: deployment)
    end

    test "send_to_device/2 returns an error when the env file was not uploaded", context do
      %{tenant: tenant, device: device, deployment: deployment, container: container} = context

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          [
            container: container,
            device: device,
            deployment: deployment,
            env_files: [%{}]
          ],
          tenant: tenant
        )
        |> Ash.create()

      [env_file] =
        Ash.load!(container_deployment, :env_files, tenant: tenant).env_files

      refute env_file.uploaded

      assert {:error, :file_not_uploaded} ==
               Core.send_to_device(env_file, tenant: tenant, deployment: deployment)
    end

    test "send_to_device/2 reloads a stale env_file struct after mark_as_uploaded and reuses linked download request on retry",
         context do
      %{tenant: tenant, device: device, deployment: deployment, container: container} = context

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          [
            container: container,
            device: device,
            deployment: deployment,
            env_files: [%{}]
          ],
          tenant: tenant
        )
        |> Ash.create()

      [stale_env_file] =
        Ash.load!(container_deployment, :env_files, tenant: tenant).env_files

      refute stale_env_file.uploaded
      assert stale_env_file.file_download_request_id == nil

      assert {:error, :file_not_uploaded} ==
               Core.send_to_device(stale_env_file, tenant: tenant, deployment: deployment)

      {:ok, _uploaded_env_file} =
        stale_env_file
        |> Ash.Changeset.for_update(:mark_as_uploaded, %{
          file_name: "config.env",
          uncompressed_file_size_bytes: 64,
          digest: "sha256:1234",
          encoding: ""
        })
        |> Ash.update(tenant: tenant)

      expect(CreateEnvFile, :send_env_file, 2, fn _client, _device_id, data ->
        assert data.id == stale_env_file.id
        assert data.deploymentId == deployment.id
        assert data.targetType == "storage"

        :ok
      end)

      assert :ok ==
               Core.send_to_device(stale_env_file, tenant: tenant, deployment: deployment)

      first_linked = Ash.get!(EnvFile, stale_env_file.id, tenant: tenant)
      assert first_linked.file_download_request_id != nil

      assert :ok ==
               Core.send_to_device(stale_env_file, tenant: tenant, deployment: deployment)

      second_linked = Ash.get!(EnvFile, stale_env_file.id, tenant: tenant)
      assert second_linked.file_download_request_id == first_linked.file_download_request_id
    end

    test "reconcile/2 marks the env file as available when the device reports it", context do
      %{tenant: tenant, device: device} = context

      container_deployment = container_deployment_fixture(tenant: tenant, device_id: device.id)

      {:ok, env_file} =
        EnvFile
        |> Ash.Changeset.for_create(
          :create,
          %{
            container_deployment_id: container_deployment.id,
            device_id: device.id,
            file_name: "config.env"
          },
          tenant: tenant
        )
        |> Ash.create()

      expect(AvailableEnvFiles, :get, fn _client, _device_id ->
        {:ok, [%EnvFileStatus{id: env_file.id}]}
      end)

      assert {:ok, updated} = Core.reconcile(env_file, tenant: tenant)
      assert updated.id == env_file.id
      assert updated.state == :available
    end

    test "reconcile/2 returns :not_found when the device does not report the env file", context do
      %{tenant: tenant, device: device} = context

      container_deployment = container_deployment_fixture(tenant: tenant, device_id: device.id)

      {:ok, env_file} =
        EnvFile
        |> Ash.Changeset.for_create(
          :create,
          %{
            container_deployment_id: container_deployment.id,
            device_id: device.id,
            file_name: "config.env"
          },
          tenant: tenant
        )
        |> Ash.create()

      expect(AvailableEnvFiles, :get, fn _client, _device_id ->
        {:ok, []}
      end)

      assert :not_found == Core.reconcile(env_file, tenant: tenant)
    end

    test "temporary_error?/1 returns true for :file_not_uploaded", _context do
      assert Core.temporary_error?(:file_not_uploaded)
      assert Core.temporary_error?({:error, :file_not_uploaded})
    end

    test "temporary_error?/1 returns false for other unspecified errors", _context do
      refute Core.temporary_error?(:other_unspecified_error)
    end
  end
end
