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

defmodule Edgehog.Containers.Network.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource, AshStateMachine]

  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Network.Changes
  alias Edgehog.Devices.Device

  state_machine do
    initial_states([:init, :sent])
    default_initial_state(:init)

    transitions do
      transition(:available, from: [:sent, :unavailable], to: :available)
      transition(:unavailable, from: [:sent, :available], to: :unavailable)
      transition(:errored, from: [:*], to: :error)
    end
  end

  graphql do
    type :network_deployment
  end

  actions do
    defaults [:read, :destroy]

    create :deploy do
      description """
      Deploys an image on a device, the status according to device triggers.
      """

      accept [:network_id]

      argument :device_id, :id do
        allow_nil? false
      end

      change manage_relationship(:device_id, :device, type: :append)
      change Changes.DeployNetworkOnDevice
    end

    update :sent do
      change transition_state(:sent)
    end

    update :available do
      change transition_state(:available)
    end

    update :unavailable do
      change transition_state(:unavailable)
    end

    update :errored do
      argument :message, :string do
        allow_nil? false
      end

      change set_attribute(:last_message, arg(:message))
      change transition_state(:error)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :last_message, :string

    timestamps()
  end

  relationships do
    belongs_to :network, Network do
      attribute_type :uuid
      public? true
    end

    belongs_to :device, Device
  end

  identities do
    identity :network_instance, [:network_id, :device_id]
  end

  postgres do
    table "network_deployments"

    references do
      reference :network, on_delete: :delete
      reference :device, on_delete: :delete
    end
  end
end
