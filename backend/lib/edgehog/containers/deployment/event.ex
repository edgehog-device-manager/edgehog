#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Event do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Deployment.EventType

  graphql do
    type :deployment_event
  end

  actions do
    defaults [
      :read,
      create: [:deployment_id, :type, :message, :add_info]
    ]
  end

  attributes do
    uuid_primary_key :id

    attribute :type, EventType do
      public? true
      allow_nil? false
    end

    attribute :message, :string do
      public? true
    end

    attribute :add_info, {:array, :string} do
      public? true
    end

    timestamps do
      public? true
    end
  end

  relationships do
    belongs_to :deployment, Edgehog.Containers.Deployment do
      attribute_type :uuid
      allow_nil? false
    end
  end

  postgres do
    table "deployment_events"

    references do
      reference :deployment, on_delete: :delete
    end
  end
end
