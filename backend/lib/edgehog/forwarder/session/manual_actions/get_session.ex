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

defmodule Edgehog.Forwarder.Session.ManualActions.GetSession do
  use Ash.Resource.ManualRead

  alias Edgehog.Devices.Device
  alias Edgehog.Forwarder.Session

  def read(ash_query, _ecto_query, _opts, context) do
    %{tenant: tenant} = context

    %Ash.Query{
      arguments: %{
        token: session_token,
        device_id: device_id
      }
    } = ash_query

    with {:ok, device} <- Ash.get(Device, device_id, tenant: tenant, load: :forwarder_sessions) do
      case get_session_by_token(device.forwarder_sessions, session_token) do
        nil -> {:ok, []}
        session -> {:ok, [session]}
      end
    end
  end

  defp get_session_by_token(sessions, session_token)
       when is_list(sessions) and is_binary(session_token) do
    case Enum.find(sessions, &(&1.token == session_token)) do
      nil ->
        nil

      session ->
        %Session{
          token: session.token,
          status: session.status,
          forwarder_hostname: session.forwarder_hostname,
          forwarder_port: session.forwarder_port,
          secure: session.secure
        }
    end
  end
end
