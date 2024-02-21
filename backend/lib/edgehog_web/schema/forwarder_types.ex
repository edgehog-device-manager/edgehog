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

defmodule EdgehogWeb.Schema.ForwarderSessionsTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Resolvers

  @desc """
  The status of a forwarder session
  """
  enum :forwarder_session_status do
    @desc "The device is connected to the forwarder."
    value :connected
    @desc "The device is connecting to the forwarder."
    value :connecting
  end

  @desc """
  The details of a forwarder session
  """
  object :forwarder_session do
    @desc "The token that identifies the session."
    field :token, non_null(:string)
    @desc "The status of the session."
    field :status, non_null(:forwarder_session_status)
    @desc "Indicates if TLS is used when the device connects to the forwarder."
    field :secure, non_null(:boolean)
    @desc "The hostname of the forwarder instance."
    field :forwarder_hostname, non_null(:string)
    @desc "The port of the forwarder instance."
    field :forwarder_port, non_null(:integer)
  end

  object :forwarder_sessions_queries do
    @desc "Fetches a forwarder session by its token and the device ID."
    field :forwarder_session, :forwarder_session do
      @desc "The GraphQL ID of the device corresponding to the session."
      arg :device_id, non_null(:id)
      @desc "The token that identifies the session."
      arg :session_token, non_null(:string)

      middleware Absinthe.Relay.Node.ParseIDs, device_id: :device
      resolve &Resolvers.ForwarderSessions.find_forwarder_session/2
    end
  end
end
