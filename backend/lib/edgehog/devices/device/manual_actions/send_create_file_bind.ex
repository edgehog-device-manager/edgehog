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
         {:ok, device} <- Ash.load(device, :appengine_client),
         {:ok, target_id} <- fetch_bind_target_id(file_bind),
         {:ok, target_type} <- fetch_bind_target_type(file_bind) do
      data = %BindRequestData{
        id: file_bind.id,
        targetId: target_id,
        targetType: target_type,
        deploymentId: deployment.id,
        mountpoint: file_bind.file_mount.mountpoint,
        options: ""
      }

      with :ok <- CreateBind.send_bind(device.appengine_client, device.device_id, data) do
        {:ok, device}
      end
    end
  end

  defp fetch_bind_target_id(%{file_download_request_id: id}) when is_binary(id),
    do: {:ok, id}

  defp fetch_bind_target_id(%{device_file_id: id}) when is_binary(id), do: {:ok, id}

  defp fetch_bind_target_id(%{id: id}),
    do: {:error, "file bind #{id} has no target: the uploaded file was not provisioned"}

  # NOTE: for the time being the type is always storage. The ID is
  # correctly resolved when using file download requests on the device
  # side.
  defp fetch_bind_target_type(_file_bind), do: {:ok, "storage"}
end
