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

defmodule Edgehog.Containers.Container.Deployment.FileBindUploadTest do
  @moduledoc """
  Tests target-less file binds: creation without a target, presigned upload
  URL calculation, marking as uploaded and automatic file download request
  provisioning at deployment time.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.FileDownloadRequest, as: AstarteFileDownloadRequest
  alias Edgehog.Astarte.Device.FileTransferCapabilities
  alias Edgehog.Containers.Container.Deployment
  alias Edgehog.Containers.Container.Deployment.Orchestrator.Core, as: OrchestratorCore
  alias Edgehog.Containers.FileBind
  alias Edgehog.Containers.FileBind.Provisioner.Core, as: FileBindProvisionerCore
  alias Edgehog.Files.FileDownloadRequest, as: StoredFileDownloadRequest
  alias Edgehog.Files.FileDownloadRequest.Provisioner, as: FileDownloadRequestProvisioner
  alias Edgehog.Files.FileDownloadRequest.Provisioner.Core, as: FileProvisionerCore
  alias Edgehog.Storage

  setup do
    Mimic.stub(FileTransferCapabilities, :get, fn _client, _device_id ->
      {:ok,
       %FileTransferCapabilities{
         unix_permissions: false,
         server_to_device: %{storage: [], streaming: nil, filesystem: nil},
         device_to_server: %{storage: nil, streaming: nil, filesystem: nil}
       }}
    end)

    Mimic.stub(AstarteFileDownloadRequest, :request_download, fn _client,
                                                                 _device_id,
                                                                 _request_data ->
      :ok
    end)

    # Don't start a real download request provisioner: these tests only cover
    # request creation and linking, and async tests cannot share the SQL
    # sandbox connection with spawned provisioner processes.
    Mimic.stub(FileDownloadRequestProvisioner, :provision, fn _request, _tenant ->
      {:ok, self()}
    end)

    :ok
  end

  defp container_with_mount(tenant, mountpoint) do
    [tenant: tenant, file_mounts: [%{mountpoint: mountpoint, required: true}]]
    |> container_fixture()
    |> Ash.load!(:file_mounts)
  end

  defp deploy_params(container, device, deployment, opts) do
    [
      container: container,
      device: device,
      deployment: deployment,
      file_binds: Keyword.get(opts, :file_binds, [])
    ]
  end

  describe "target-less file binds" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)

      %{
        tenant: tenant,
        device: device,
        deployment: deployment_fixture(tenant: tenant, device_id: device.id)
      }
    end

    test "creates a file bind without a target as pending upload", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      container = container_with_mount(tenant, "/etc/app.conf")

      %{file_mounts: [file_mount]} = container

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment,
            file_binds: [%{file_mount_id: file_mount.id}]
          ),
          tenant: tenant
        )
        |> Ash.create()

      [file_bind] =
        Ash.load!(container_deployment, :file_binds, tenant: tenant).file_binds

      assert file_bind.file_download_request_id == nil
      assert file_bind.device_file_id == nil
      refute file_bind.uploaded
      assert file_bind.device_id == device.id
      assert file_bind.state == :created
    end

    test "returns a presigned upload URL for a target-less file bind", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      Mimic.stub(Storage, :create_presigned_urls, fn path ->
        assert String.contains?(
                 path,
                 "uploads/tenants/#{tenant.tenant_id}/file_binds/"
               )

        # The object key does not depend on the file name, which is only
        # known when the upload is marked as uploaded
        assert String.ends_with?(path, "/file")

        {:ok,
         %{
           put_url: "http://example.test/upload",
           get_url: "http://example.test/download"
         }}
      end)

      container = container_with_mount(tenant, "/etc/app.conf")

      %{file_mounts: [file_mount]} = container

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment,
            file_binds: [%{file_mount_id: file_mount.id}]
          ),
          tenant: tenant
        )
        |> Ash.create()

      [file_bind] =
        Ash.load!(container_deployment, :file_binds, tenant: tenant).file_binds

      %{upload_url: upload_url} =
        Ash.load!(file_bind, :upload_url, tenant: tenant)

      assert upload_url == "http://example.test/upload"
    end

    test "marks the file as uploaded with client-supplied metadata", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      container = container_with_mount(tenant, "/etc/app.conf")

      %{file_mounts: [file_mount]} = container

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment,
            file_binds: [%{file_mount_id: file_mount.id}]
          ),
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

      assert file_bind.uploaded
      assert file_bind.file_name == "app.conf"
      assert file_bind.uncompressed_file_size_bytes == 128
      assert file_bind.digest == "sha256:abcd"
    end

    test "rejects a file bind with both a request and a device file", context do
      %{tenant: tenant, device: device} = context

      file_request = manual_file_download_request_fixture(tenant: tenant, device_id: device.id)
      device_file = device_file_fixture(tenant: tenant, device_id: device.id)

      container = container_with_mount(tenant, "/etc/app.conf")

      %{file_mounts: [file_mount]} = container

      container_deployment = container_deployment_fixture(tenant: tenant, device_id: device.id)

      assert {:error, _} =
               FileBind
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   container_deployment_id: container_deployment.id,
                   file_mount_id: file_mount.id,
                   file_download_request_id: file_request.id,
                   device_file_id: device_file.id
                 },
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "deploying an uploaded bind creates and links a file download request", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      Mimic.stub(Storage, :read_presigned_url, fn _path ->
        {:ok, %{get_url: "http://example.test/download"}}
      end)

      container = container_with_mount(tenant, "/etc/app.conf")

      %{file_mounts: [file_mount]} = container

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment,
            file_binds: [%{file_mount_id: file_mount.id}]
          ),
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

      # Simulate what the container deployment orchestrator does for
      # target-less binds: create the file download request and link it.
      {:ok, file_download_request} =
        Edgehog.Files.create_file_bind_file_download_request(
          %{
            url: "http://example.test/download",
            file_name: file_bind.file_name,
            uncompressed_file_size_bytes: file_bind.uncompressed_file_size_bytes,
            digest: file_bind.digest,
            encoding: file_bind.encoding,
            destination_type: :storage,
            device_id: device.id
          },
          tenant: tenant
        )

      assert file_download_request.manual?

      {:ok, file_bind} =
        file_bind
        |> Ash.Changeset.for_update(:link_file_download_request, %{
          file_download_request_id: file_download_request.id
        })
        |> Ash.update(tenant: tenant)

      stored =
        Ash.get!(StoredFileDownloadRequest, file_bind.file_download_request_id, tenant: tenant)

      assert stored.id == file_download_request.id
      assert stored.url == "http://example.test/download"
    end
  end

  describe "file provisioning" do
    test "file provisioner is ready only when the download completed" do
      assert FileProvisionerCore.ready?(%{status: :completed})
      refute FileProvisionerCore.ready?(%{status: :pending})
      refute FileProvisionerCore.ready?(%{status: :sent})
      refute FileProvisionerCore.ready?(%{status: :in_progress})
      refute FileProvisionerCore.ready?(%{status: :failed})
    end

    test "file provisioner topics are distinct from resource topics" do
      id = Ash.UUIDv7.generate()

      assert FileProvisionerCore.topic(%{id: id}) == "ready:file_download_requests:#{id}"
      assert FileProvisionerCore.subscribe_topic(%{id: id}) == "file_download_requests:#{id}"
    end

    test "orchestrator tracks file bind readiness like other resources" do
      first = %{id: Ash.UUIDv7.generate()}
      second = %{id: Ash.UUIDv7.generate()}

      state = %{file_binds_to_provision: [first, second]}

      state = OrchestratorCore.file_bind_ready(first.id, state)
      assert state.file_binds_to_provision == [second]

      state = OrchestratorCore.file_bind_ready(second.id, state)
      assert state.file_binds_to_provision == []
    end

    test "file bind provisioner is ready only when the device reports it" do
      assert FileBindProvisionerCore.ready?(%{state: :available})
      assert FileBindProvisionerCore.ready?(%{state: :unavailable})
      refute FileBindProvisionerCore.ready?(%{state: :created})
      refute FileBindProvisionerCore.ready?(%{state: :sent})
    end

    test "file bind provisioner topics are distinct from resource topics" do
      id = Ash.UUIDv7.generate()

      assert FileBindProvisionerCore.topic(%{id: id}) == "ready:file_binds:#{id}"
      assert FileBindProvisionerCore.subscribe_topic(%{id: id}) == "file_binds:#{id}"

      assert FileBindProvisionerCore.name(%{id: id}) ==
               {:via, Registry, {Edgehog.Containers.FileBind.Provisioner.Registry, id}}
    end
  end
end
