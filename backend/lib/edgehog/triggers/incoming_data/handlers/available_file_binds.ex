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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailableFileBinds do
  @moduledoc """
  Available FileBinds handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", bind_id, _field] -> handle_bind_event(bind_id, event.value, device, tenant)
      _ -> {:error, :invalid_event_path}
    end
  end

  defp handle_bind_event(bind_id, value, device, tenant) do
    file_bind = Containers.fetch_file_bind!(bind_id, tenant: tenant)

    file_bind =
      Ash.load!(file_bind, [container_deployment: [:device_id]], tenant: tenant)

    if file_bind.container_deployment.device_id != device.id do
      {:error, :device_mismatch}
    else
      update_file_bind(file_bind, value, tenant)
    end
  end

  defp update_file_bind(file_bind, nil, tenant) do
    Containers.destroy_file_bind!(file_bind, tenant: tenant)
    {:ok, file_bind}
  end

  defp update_file_bind(file_bind, _value, tenant) do
    Containers.mark_file_bind_as_available(file_bind, tenant: tenant)
  end
end
