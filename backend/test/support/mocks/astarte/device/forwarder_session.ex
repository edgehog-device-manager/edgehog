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

defmodule Edgehog.Mocks.Astarte.Device.ForwarderSession do
  @behaviour Edgehog.Astarte.Device.ForwarderSession.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.ForwarderSession

  @forwarder_hostname "localhost"
  @forwarder_port 4001
  @secure_sessions? false

  @impl true
  def list_sessions(%AppEngine{} = _client, _device_id) do
    sessions = [
      %ForwarderSession{
        token: "session_token_1",
        status: :connecting,
        secure: @secure_sessions?,
        forwarder_hostname: @forwarder_hostname,
        forwarder_port: @forwarder_port
      },
      %ForwarderSession{
        token: "session_token_2",
        status: :connected,
        secure: @secure_sessions?,
        forwarder_hostname: @forwarder_hostname,
        forwarder_port: @forwarder_port
      }
    ]

    {:ok, sessions}
  end

  @impl true
  def fetch_session(%AppEngine{} = _client, _device_id, session_token) do
    session = %ForwarderSession{
      token: session_token,
      status: :connected,
      secure: @secure_sessions?,
      forwarder_hostname: @forwarder_hostname,
      forwarder_port: @forwarder_port
    }

    {:ok, session}
  end

  @impl true
  def request_session(
        %AppEngine{} = _client,
        _device_id,
        _session_token,
        _forwarder_hostname,
        _forwarder_port,
        _forwarder_secure_sessions?
      ) do
    :ok
  end
end
