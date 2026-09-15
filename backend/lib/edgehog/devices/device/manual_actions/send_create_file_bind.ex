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

defmodule Edgehog.Devices.Device.ManualActions.SendCreateFileBind do
  @moduledoc false
  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.CreateBind
  alias Edgehog.Astarte.Device.CreateBind.RequestData, as: BindRequestData

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    with {:ok, deployment} <- Ash.Changeset.fetch_argument(changeset, :deployment),
         {:ok, file_bind} <- Ash.Changeset.fetch_argument(changeset, :file_bind),
         {:ok, file_bind} <- Ash.load(file_bind, file_mount: :mountpoint),
         {:ok, device} <- Ash.load(device, :appengine_client) do
      data = %BindRequestData{
        id: file_bind.id,
        targetId: bind_target_id(file_bind),
        targetType: bind_target_type(file_bind),
        deploymentId: deployment.id,
        mountpoint: file_bind.file_mount.mountpoint,
        options: ""
      }

      with :ok <- CreateBind.send_bind(device.appengine_client, device.device_id, data) do
        {:ok, device}
      end
    end
  end

  defp bind_target_id(%{file_download_request_id: id} = file_bind) do
    id || file_bind.device_file_id ||
      raise ArgumentError,
            "file bind #{file_bind.id} has no target: the uploaded file was not provisioned"
  end

  defp bind_target_type(%{device_file_id: device_file_id}) when is_nil(device_file_id),
    do: "request"

  defp bind_target_type(_file_bind), do: "storage"
end
