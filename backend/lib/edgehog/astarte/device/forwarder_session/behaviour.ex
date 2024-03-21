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

defmodule Edgehog.Astarte.Device.ForwarderSession.Behaviour do
  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.ForwarderSession

  @callback list_sessions(client :: AppEngine.t(), device_id :: String.t()) ::
              {:ok, list(ForwarderSession.t())} | {:error, term()}

  @callback fetch_session(
              client :: AppEngine.t(),
              device_id :: String.t(),
              session_token :: String.t()
            ) ::
              {:ok, ForwarderSession.t()} | {:error, term()}

  @callback request_session(
              client :: AppEngine.t(),
              device_id :: String.t(),
              session_token :: String.t(),
              forwarder_hostname :: String.t(),
              forwarder_port :: integer(),
              secure_sessions? :: boolean()
            ) ::
              :ok | {:error, term()}
end
