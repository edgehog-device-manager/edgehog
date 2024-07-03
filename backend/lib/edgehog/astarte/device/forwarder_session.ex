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

defmodule Edgehog.Astarte.Device.ForwarderSession do
  @enforce_keys [:token, :status, :secure, :forwarder_hostname, :forwarder_port]
  defstruct @enforce_keys

  @behaviour Edgehog.Astarte.Device.ForwarderSession.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Forwarder.Session

  @session_request_interface "io.edgehog.devicemanager.ForwarderSessionRequest"
  @sessions_state_interface "io.edgehog.devicemanager.ForwarderSessionState"

  @impl Edgehog.Astarte.Device.ForwarderSession.Behaviour
  def list_sessions(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_properties_data(client, device_id, @sessions_state_interface) do
      sessions = parse_session_list(data)

      {:ok, sessions}
    end
  end

  @impl Edgehog.Astarte.Device.ForwarderSession.Behaviour
  def request_session(
        %AppEngine{} = client,
        device_id,
        session_token,
        forwarder_hostname,
        forwarder_port,
        forwarder_secure_sessions?
      )
      when is_binary(session_token) and is_binary(forwarder_hostname) and
             is_integer(forwarder_port) and is_boolean(forwarder_secure_sessions?) do
    data = %{
      session_token: session_token,
      host: forwarder_hostname,
      port: forwarder_port,
      secure: forwarder_secure_sessions?
    }

    AppEngine.Devices.send_datastream(
      client,
      device_id,
      @session_request_interface,
      "/request",
      data
    )
  end

  defp parse_session_list(session_states) do
    Enum.map(session_states, fn {session_token, session_state} ->
      parse_session(session_token, session_state)
    end)
  end

  defp parse_session(session_token, session_state) do
    %Session{
      token: session_token,
      status: parse_session_status(session_state["status"]),
      # TODO: forwarder info should be specified in the session_state.
      # See issue: https://github.com/edgehog-device-manager/edgehog-astarte-interfaces/issues/68
      secure: forwarder_secure_sessions?(),
      forwarder_hostname: forwarder_hostname(),
      forwarder_port: forwarder_port()
    }
  end

  defp parse_session_status("Connected"), do: :connected
  defp parse_session_status("Connecting"), do: :connecting

  defp forwarder_hostname do
    forwarder_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)
    forwarder_config.hostname
  end

  defp forwarder_port do
    forwarder_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)
    forwarder_config.port
  end

  defp forwarder_secure_sessions? do
    forwarder_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)
    forwarder_config.secure_sessions?
  end
end
