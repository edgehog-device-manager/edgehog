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

defmodule Edgehog.Triggers.IncomingData.Handlers.FileStorage do
  @moduledoc """
  Handles incoming Astarte trigger events related to device file storage.
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Devices
  alias Edgehog.Files

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(%{path: path, value: value}, _opts, %{tenant: tenant} = context) do
    with {:ok, file_id, property} <- parse_path(path) do
      process_event(value, file_id, property, tenant, context)
    end
  end

  # Early exit: Do not unset as we do a soft delete
  defp process_event(nil, _file_id, _property, _tenant, _context), do: :ok

  defp process_event(value, file_id, property, tenant, context) do
    with {:ok, device_file} <- ensure_device_file(file_id, context),
         {:ok, _updated_file} <- update_device_file(device_file, property, value, tenant) do
      :ok
    end
  end

  defp parse_path("/" <> rest) do
    case String.split(rest, "/", parts: 2) do
      [file_id, "pathOnDevice"] -> {:ok, file_id, :path_on_device}
      [file_id, "sizeBytes"] -> {:ok, file_id, :size_bytes}
      _ -> {:error, :invalid_event_path}
    end
  end

  defp parse_path(_), do: {:error, :invalid_event_path}

  defp ensure_device_file(file_id, %{tenant: tenant, device_id: device_id, realm_id: realm_id}) do
    case Files.fetch_device_file_by_file_id(file_id, tenant: tenant) do
      {:ok, device_file} -> {:ok, device_file}
      {:error, _reason} -> create_device_file(file_id, device_id, realm_id, tenant)
    end
  end

  defp create_device_file(file_id, device_id, realm_id, tenant) do
    with {:ok, device} <- Devices.fetch_device_by_identity(device_id, realm_id, tenant: tenant) do
      file_download_request_id =
        case Files.fetch_file_download_request(file_id, tenant: tenant) do
          {:ok, request} -> request.id
          _error -> nil
        end

      attrs = %{
        file_id: file_id,
        device_id: device.id,
        file_download_request_id: file_download_request_id
      }

      Files.create_device_file(attrs, tenant: tenant)
    end
  end

  defp update_device_file(device_file, :path_on_device, value, tenant) do
    Files.set_device_file_path_on_device(device_file, [path_on_device: value], tenant: tenant)
  end

  defp update_device_file(device_file, :size_bytes, value, tenant) do
    Files.set_device_file_size_bytes(device_file, [size_bytes: value], tenant: tenant)
  end
end
