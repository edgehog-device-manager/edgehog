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

defmodule Edgehog.Forwarder.Session.ManualActions.RequestSession do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Ash.Error.Changes.InvalidArgument
  alias Edgehog.Devices.Device
  alias Edgehog.Forwarder

  @forwarder_session_module Application.compile_env(
                              :edgehog,
                              :astarte_forwarder_session_module,
                              Edgehog.Astarte.Device.ForwarderSession
                            )

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, context) do
    %{tenant: tenant} = context
    %{arguments: %{device_id: device_id}} = input

    with {:ok, device} <-
           Ash.get(Device, device_id,
             tenant: tenant,
             load: [:online, :appengine_client, :forwarder_sessions]
           ) do
      case get_available_session(device.forwarder_sessions) do
        nil -> request_new_session_token(device)
        session -> {:ok, session.token}
      end
    end
  end

  defp get_available_session(sessions) when is_list(sessions) do
    Enum.find(sessions, &(&1.status == :connected)) ||
      Enum.find(sessions, &(&1.status == :connecting))
  end

  defp request_new_session_token(device) do
    session_token = Ash.UUID.generate()

    with {:ok, forwarder_config} <- fetch_forwarder_config(),
         :ok <- validate_device_connected(device),
         :ok <-
           @forwarder_session_module.request_session(
             device.appengine_client,
             device.device_id,
             session_token,
             forwarder_config.hostname,
             forwarder_config.port,
             forwarder_config.secure_sessions
           ) do
      {:ok, session_token}
    end
  end

  defp fetch_forwarder_config do
    Ash.read_one(Forwarder.Config, not_found_error?: true)
  end

  defp validate_device_connected(%Device{online: true}) do
    :ok
  end

  defp validate_device_connected(%Device{online: false}) do
    {:error,
     InvalidArgument.exception(
       field: :device_id,
       message: "device is disconnected"
     )}
  end
end
