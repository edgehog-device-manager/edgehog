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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailableDeviceMappings do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", device_mapping_id, "present"] ->
        device_mapping_deployment =
          Containers.fetch_device_mapping_deployment!(device_mapping_id, device.id, tenant: tenant)

        case event.value do
          true ->
            Containers.mark_device_mapping_deployment_as_present(device_mapping_deployment,
              tenant: tenant
            )

          false ->
            Containers.mark_device_mapping_deployment_as_not_present(device_mapping_deployment,
              tenant: tenant
            )

          # The device mapping has been removed on the device. We should remove it too.
          nil ->
            Containers.destroy_device_mapping_deployment(device_mapping_deployment,
              tenant: tenant
            )

            {:ok, device_mapping_deployment}
        end

      _ ->
        {:error, :invalid_event_path}
    end
  end
end
