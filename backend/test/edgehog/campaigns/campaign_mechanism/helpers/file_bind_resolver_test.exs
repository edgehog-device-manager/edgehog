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

defmodule Edgehog.Campaigns.CampaignMechanism.Helpers.FileBindsResolverTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.FileDownloadRequest, as: AstarteFileDownloadRequest
  alias Edgehog.Astarte.Device.FileTransferCapabilities
  alias Edgehog.Campaigns.CampaignMechanism.Helpers.FileBindsResolver
  alias Edgehog.Files.FileDownloadRequest
  alias Edgehog.Files.FileDownloadRequest.Provisioner, as: FileDownloadRequestProvisioner

  setup do
    stub(FileTransferCapabilities, :get, fn _client, _device_id ->
      {:ok,
       %FileTransferCapabilities{
         unix_permissions: false,
         server_to_device: %{storage: ["tar.gz"], streaming: nil, filesystem: nil},
         device_to_server: %{storage: nil, streaming: nil, filesystem: nil}
       }}
    end)

    stub(AstarteFileDownloadRequest, :request_download, fn _client, _device_id, _request_data ->
      :ok
    end)

    # Don't start a real download request provisioner: async tests cannot
    # share the SQL sandbox connection with spawned provisioner processes.
    stub(FileDownloadRequestProvisioner, :provision, fn _request, _tenant ->
      {:ok, self()}
    end)

    %{tenant: tenant_fixture()}
  end

  describe "resolve/3" do
    test "returns an empty list when no configs are provided", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)

      assert FileBindsResolver.resolve([], device.id, tenant.tenant_id) == []
    end

    test "creates a FileDownloadRequest for each managed file bind and returns its id", %{
      tenant: tenant
    } do
      device = device_fixture(tenant: tenant)

      %{config: config, file: file, file_mount: file_mount} =
        deployment_deploy_file_bind_config_fixture(tenant: tenant)

      [resolved_config] = FileBindsResolver.resolve([config], device.id, tenant.tenant_id)

      assert [resolved_bind] = resolved_config.file_binds
      assert resolved_bind.file_mount_id == file_mount.id
      assert resolved_bind.file_id == nil
      refute is_nil(resolved_bind.file_download_request_id)

      request =
        Ash.get!(FileDownloadRequest, resolved_bind.file_download_request_id,
          tenant: tenant.tenant_id
        )

      assert request.device_id == device.id
      assert request.file_name == file.name
    end

    test "resolves file binds for each config independently", %{tenant: tenant} do
      device = device_fixture(tenant: tenant)

      %{config: first_config} = deployment_deploy_file_bind_config_fixture(tenant: tenant)
      %{config: second_config} = deployment_deploy_file_bind_config_fixture(tenant: tenant)

      [first_resolved, second_resolved] =
        FileBindsResolver.resolve([first_config, second_config], device.id, tenant.tenant_id)

      [first_bind] = first_resolved.file_binds
      [second_bind] = second_resolved.file_binds

      refute is_nil(first_bind.file_download_request_id)
      refute is_nil(second_bind.file_download_request_id)
      refute first_bind.file_download_request_id == second_bind.file_download_request_id
    end

    test "leaves already-resolved file binds (with a download request id) unchanged", %{
      tenant: tenant
    } do
      device = device_fixture(tenant: tenant)

      existing_request =
        managed_file_download_request_fixture(tenant: tenant, device_id: device.id)

      %{config: config, file_mount: file_mount} =
        deployment_deploy_file_bind_config_fixture(tenant: tenant)

      config_with_resolved_bind = %{
        config
        | file_binds: [
            %{file_download_request_id: existing_request.id, file_mount_id: file_mount.id}
          ]
      }

      request_count_before = count_file_download_requests(tenant.tenant_id)

      [resolved_config] =
        FileBindsResolver.resolve([config_with_resolved_bind], device.id, tenant.tenant_id)

      assert [resolved_bind] = resolved_config.file_binds
      assert resolved_bind.file_download_request_id == existing_request.id
      assert resolved_bind.file_id == nil

      assert count_file_download_requests(tenant.tenant_id) == request_count_before
    end
  end

  defp count_file_download_requests(tenant_id) do
    FileDownloadRequest |> Ash.read!(tenant: tenant_id) |> length()
  end
end
