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

defmodule Edgehog.Campaigns.CampaignMechanism.Helpers.FileBindsResolver do
  @moduledoc """
  Resolves file references in deployment configs to download-request IDs for a device.
  """

  alias Edgehog.Files.FileDownloadRequest

  def resolve([] = configs, _device_id, _tenant_id), do: configs

  def resolve(configs, device_id, tenant_id) do
    Enum.map(configs, &resolve_file_binds(&1, device_id, tenant_id))
  end

  defp resolve_file_binds(config, device_id, tenant_id) do
    resolved_file_binds =
      Enum.map(config.file_binds, &do_resolve_file_bind(&1, device_id, tenant_id))

    %{config | file_binds: resolved_file_binds}
  end

  defp do_resolve_file_bind(%{file_download_request_id: _} = file_bind, _device_id, _tenant_id) do
    Map.put_new(file_bind, :file_id, nil)
  end

  defp do_resolve_file_bind(%{file_id: file_id} = file_bind, device_id, tenant_id) do
    opts = %{
      file_id: file_id,
      device_id: device_id,
      destination_type: "storage"
    }

    file_download_request =
      FileDownloadRequest
      |> Ash.Changeset.for_create(:managed, opts, tenant: tenant_id)
      |> Ash.create!(tenant: tenant_id)

    file_bind
    |> Map.put(:file_id, nil)
    |> Map.put(:file_download_request_id, file_download_request.id)
  end
end
