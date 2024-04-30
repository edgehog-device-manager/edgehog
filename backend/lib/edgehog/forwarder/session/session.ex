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

defmodule Edgehog.Forwarder.Session do
  use Ash.Resource,
    domain: Edgehog.Forwarder,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.Forwarder.Session.ManualActions
  alias Edgehog.Forwarder.Session.Status

  resource do
    description "The details of a forwarder session."
  end

  graphql do
    type :forwarder_session

    derive_filter? false
    derive_sort? false

    queries do
      read_one :forwarder_session, :get do
        relay_id_translations device_id: :device
      end
    end

    mutations do
      action :request_forwarder_session, :request do
        relay_id_translations input: [device_id: :device]
      end
    end
  end

  actions do
    read :get do
      description "Fetches a forwarder session by its token and the device ID."
      get? true

      argument :token, :string, allow_nil?: false
      argument :device_id, :id, allow_nil?: false

      manual ManualActions.GetSession
    end

    action :request, :string do
      description """
      Requests a forwarder session for the specified device.
      Returns the session token.
      """

      argument :device_id, :id, allow_nil?: false

      run ManualActions.RequestSession
    end
  end

  attributes do
    attribute :token, :string do
      description "The token that identifies the session."
      public? true
      primary_key? true
      allow_nil? false
    end

    attribute :status, Status do
      description "The status of the session."
      public? true
      allow_nil? false
    end

    attribute :forwarder_hostname, :string do
      description "The hostname of the forwarder instance."
      public? true
      allow_nil? false
    end

    attribute :forwarder_port, :integer do
      description "The port of the forwarder instance."
      public? true
      allow_nil? false
    end

    attribute :secure, :boolean do
      description "Indicates if TLS is used when the device connects to the forwarder."
      public? true
      allow_nil? false
    end
  end
end
