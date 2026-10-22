# This file is part of Edgehog.
#
# Copyright 2024, 2026 SECO Mind Srl
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

defmodule Edgehog.Forwarder.Session.ManualActions.GetSession do
  @moduledoc false
  use Ash.Resource.ManualRead

  alias Edgehog.Devices.Device
  alias Edgehog.Forwarder.Guardian, as: ForwarderGuardian
  alias Edgehog.Forwarder.Session

  # NOTE: `session` is handled separately, as it actually maps to the session token
  @action_args [:protocol, :host, :port, :insecure_tls_config]

  def read(ash_query, _ecto_query, _opts, context) do
    %{tenant: tenant} = context

    %Ash.Query{arguments: arguments} = ash_query

    %{device_id: device_id} = arguments

    with {:ok, device} <- Ash.get(Device, device_id, tenant: tenant, load: :forwarder_sessions),
         {:ok, session} <- fetch_session_by_token(device.forwarder_sessions, arguments) do
      case session do
        nil -> {:ok, []}
        session -> {:ok, [session]}
      end
    end
  end

  defp fetch_session_by_token(sessions, conn_args) when is_list(sessions) and is_map(conn_args) do
    %{token: session_token} = conn_args

    sessions
    |> Enum.find(&(&1.token == session_token))
    |> maybe_gen_session(conn_args)
  end

  defp maybe_gen_session(nil, _conn_args), do: {:ok, nil}

  defp maybe_gen_session(session, conn_args) do
    args =
      conn_args
      |> Map.take(@action_args)
      |> Map.put(:session, session.token)

    with {:ok, jwt, _claims} <- ForwarderGuardian.encode_and_sign(:forwarder_session, args) do
      session = %Session{
        token: jwt,
        status: session.status,
        forwarder_hostname: session.forwarder_hostname,
        forwarder_port: session.forwarder_port,
        secure: session.secure
      }

      {:ok, session}
    end
  end
end
