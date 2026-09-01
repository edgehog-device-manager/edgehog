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

defmodule Edgehog.Containers.Container.Deployment.FileMountAndEnvTest do
  @moduledoc """
  Tests the resolution of file mounts binds and environment variables on a
  Container.Deployment created through the deploy action.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.FileDownloadRequest
  alias Edgehog.Astarte.Device.FileTransferCapabilities
  alias Edgehog.Containers.Container.Deployment
  alias Edgehog.Files.FileDownloadRequest, as: StoredFileDownloadRequest

  setup do
    Mimic.stub(FileTransferCapabilities, :get, fn _client, _device_id ->
      {:ok,
       %FileTransferCapabilities{
         unix_permissions: false,
         server_to_device: %{storage: [], streaming: nil, filesystem: nil},
         device_to_server: %{storage: nil, streaming: nil, filesystem: nil}
       }}
    end)

    Mimic.stub(FileDownloadRequest, :request_download, fn _client, _device_id, _request_data ->
      :ok
    end)

    Mimic.stub(Edgehog.Files.EphemeralFile, :upload, fn _tenant_id,
                                                        _file_download_request_id,
                                                        _upload ->
      {:ok, "https://example.com/ephemeral/#{System.unique_integer([:positive])}"}
    end)

    :ok
  end

  defp deploy_params(container, device, deployment, opts) do
    [
      container: container,
      device: device,
      deployment: deployment,
      env: Keyword.get(opts, :env, []),
      env_strategy: Keyword.get(opts, :env_strategy, :merge),
      file_binds: Keyword.get(opts, :file_binds, [])
    ]
  end

  describe "deploy with file mounts" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)
      file = file_fixture(tenant: tenant)

      %{
        tenant: tenant,
        device: device,
        default_file: file,
        deployment: deployment_fixture(tenant: tenant, device_id: device.id)
      }
    end

    @tag skip: "TODO: update/unskip the test when we support this flow"
    test "creates a managed file bind for a mount with a default file", context do
      %{tenant: tenant, device: device, default_file: file, deployment: deployment} = context

      container =
        container_fixture(
          tenant: tenant,
          file_mounts: [
            %{mountpoint: "/etc/default.conf", required: true, default_file_id: file.id}
          ]
        )

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment, []),
          tenant: tenant
        )
        |> Ash.create()

      container_deployment =
        Ash.load!(container_deployment, [file_binds: [file_mount: :mountpoint]], tenant: tenant)

      [file_bind] = container_deployment.file_binds
      assert file_bind.file_mount.mountpoint == "/etc/default.conf"

      request =
        Ash.get!(StoredFileDownloadRequest, file_bind.file_download_request_id, tenant: tenant)

      refute request.manual?
      assert request.device_id == device.id
    end

    test "creates a manual file bind for a user-provided upload", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      file_request = manual_file_download_request_fixture(tenant: tenant, device_id: device.id)

      container =
        [
          tenant: tenant,
          file_mounts: [%{mountpoint: "/etc/app.conf", required: true}]
        ]
        |> container_fixture()
        |> Ash.load!(:file_mounts)

      %{file_mounts: [file_mount]} = container

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment,
            file_binds: [
              %{
                file_mount_id: file_mount.id,
                file_download_request_id: file_request.id
              }
            ]
          ),
          tenant: tenant
        )
        |> Ash.create()

      container_deployment =
        Ash.load!(container_deployment, [file_binds: :file_mount], tenant: tenant)

      [file_bind] = container_deployment.file_binds

      assert file_bind.file_mount.mountpoint == "/etc/app.conf"
      assert file_bind.file_download_request_id == file_request.id
    end

    test "fails to deploy when a required mount has no file", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      container =
        container_fixture(
          tenant: tenant,
          file_mounts: [%{mountpoint: "/etc/app.conf", required: true}]
        )

      result =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment, []),
          tenant: tenant
        )
        |> Ash.create()

      assert {:error, %Ash.Error.Invalid{errors: errors}} = result

      [error] = errors

      assert %Ash.Error.Changes.InvalidArgument{field: :file_binds} = error
    end

    test "skips non-required mounts without a file", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      container =
        container_fixture(
          tenant: tenant,
          file_mounts: [%{mountpoint: "/etc/optional.conf", required: false}]
        )

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment, []),
          tenant: tenant
        )
        |> Ash.create()

      container_deployment = Ash.load!(container_deployment, :file_binds, tenant: tenant)
      assert container_deployment.file_binds == []
    end
  end

  describe "deploy with environment" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)

      %{
        tenant: tenant,
        device: device,
        deployment: deployment_fixture(tenant: tenant, device_id: device.id)
      }
    end

    test "merges container env with deploy env, deploy env wins on duplicate keys", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      container =
        container_fixture(
          tenant: tenant,
          env: [%{key: "A", value: "1"}, %{key: "B", value: "2"}]
        )

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(container, device, deployment,
            env: [
              %{key: "B", value: "3"},
              %{key: "C", value: "4"}
            ]
          ),
          tenant: tenant
        )
        |> Ash.create()

      assert container_deployment.env == [
               %{key: "A", value: "1"},
               %{key: "B", value: "3"},
               %{key: "C", value: "4"}
             ]

      assert container_deployment.env_strategy == :merge
    end

    test "overrides container env with deploy env", context do
      %{tenant: tenant, device: device, deployment: deployment} = context

      container =
        container_fixture(
          tenant: tenant,
          env: [%{key: "A", value: "1"}]
        )

      {:ok, container_deployment} =
        Deployment
        |> Ash.Changeset.for_create(
          :deploy,
          deploy_params(
            container,
            device,
            deployment,
            env: [%{key: "B", value: "2"}],
            env_strategy: :override
          ),
          tenant: tenant
        )
        |> Ash.create()

      assert container_deployment.env == [%{key: "B", value: "2"}]
      assert container_deployment.env_strategy == :override
    end
  end
end
