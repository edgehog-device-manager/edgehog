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

defmodule Edgehog.Files.FileDownloadRequest.Validations.CheckEncoding do
  @moduledoc false

  use Ash.Resource.Validation
  alias Edgehog.Devices.Device

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant} = _context) do
    encoding = Ash.Changeset.get_attribute(changeset, :encoding)
    destination_type = Ash.Changeset.get_attribute(changeset, :destination_type)
    device_id = Ash.Changeset.get_argument(changeset, :device_id)

    with {:ok, capabilities} <- get_device_file_transfer_capabilities(device_id, tenant) do
      check_valid_encoding(encoding, destination_type, capabilities)
    end
  end

  defp get_device_file_transfer_capabilities(device_id, tenant) do
    case Ash.get(Device, device_id, tenant: tenant) do
      {:ok, device} ->
        capabilities =
          device
          |> Ash.load!(:file_transfer_capabilities)
          |> Map.get(:file_transfer_capabilities)

        {:ok, capabilities}

      {:error,
       %Ash.Error.Invalid{
         errors: [
           %Ash.Error.Query.NotFound{}
         ]
       }} = error ->
        error
    end
  end

  defp check_valid_encoding(
         encoding,
         destination_type,
         %{server_to_device: server_to_device} = _capabilities
       ) do
    target = parse_destination_type(destination_type)

    case Map.get(server_to_device, target) do
      nil ->
        {:error, "Target #{target} not supported for server-to-device transfers"}

      target_encodings when is_list(target_encodings) ->
        cond do
          encoding in [nil, ""] ->
            :ok

          encoding in target_encodings ->
            :ok

          true ->
            {:error, "Encoding type not supported by device for this target"}
        end
    end
  end

  defp parse_destination_type(nil), do: :storage
  defp parse_destination_type(dest) when is_atom(dest), do: dest
  defp parse_destination_type("storage"), do: :storage
  defp parse_destination_type("streaming"), do: :streaming
  defp parse_destination_type("filesystem"), do: :filesystem
  defp parse_destination_type(_), do: :storage

  @impl Ash.Resource.Validation
  def batch_callbacks?(_changeset, _opts, _context), do: false

  @impl Ash.Resource.Validation
  def has_batch_validate?, do: false
end
