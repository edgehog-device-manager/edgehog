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

defmodule Edgehog.Forwarder.Config do
  @moduledoc false
  use Ash.Resource,
    domain: Edgehog.Forwarder,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.Forwarder.Config.ManualActions

  resource do
    description "The details of a forwarder instance."
  end

  graphql do
    type :forwarder_config

    derive_filter? false
    derive_sort? false
  end

  actions do
    read :get do
      description """
      Fetches the forwarder config, if available.
      Without a configuration, forwarding functionalities are not available.
      """

      primary? true
      get? true

      manual ManualActions.GetConfig
    end
  end

  attributes do
    attribute :hostname, :string do
      description "The hostname of the forwarder instance."
      public? true
      primary_key? true
      allow_nil? false
    end

    attribute :port, :integer do
      description "The port of the forwarder instance."
      public? true
      primary_key? true
      allow_nil? false
    end

    attribute :secure_sessions, :boolean do
      description "Indicates if TLS should used when connecting to the forwarder."
      public? true
      allow_nil? false
    end
  end
end
