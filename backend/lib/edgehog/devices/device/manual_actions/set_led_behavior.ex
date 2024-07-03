#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.ManualActions.SetLedBehavior do
  use Ash.Resource.ManualUpdate

  alias Edgehog.Error.AstarteAPIError

  @led_behavior Application.compile_env(
                  :edgehog,
                  :astarte_led_behavior_module,
                  Edgehog.Astarte.Device.LedBehavior
                )

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    behavior = changeset.arguments.behavior
    device = changeset.data

    with {:ok, led_behavior} <- led_behavior_from_enum(behavior),
         {:ok, device} <- Ash.load(device, :appengine_client),
         :ok <- @led_behavior.post(device.appengine_client, device.device_id, led_behavior) do
      {:ok, device}
    else
      {:error, %Astarte.Client.APIError{} = api_error} ->
        reason =
          AstarteAPIError.exception(
            status: api_error.status,
            response: api_error.response
          )

        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp led_behavior_from_enum(:blink), do: {:ok, "Blink60Seconds"}
  defp led_behavior_from_enum(:double_blink), do: {:ok, "DoubleBlink60Seconds"}
  defp led_behavior_from_enum(:slow_blink), do: {:ok, "SlowBlink60Seconds"}
  defp led_behavior_from_enum(_), do: {:error, "Unknown led behavior"}
end
