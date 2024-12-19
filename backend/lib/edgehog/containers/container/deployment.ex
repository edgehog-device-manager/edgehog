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

defmodule Edgehog.Containers.Container.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource, AshStateMachine]

  alias Edgehog.Containers.Container.Changes

  state_machine do
    initial_states([:init, :sent])
    default_initial_state(:init)

    transitions do
      transition(:received, from: :sent, to: :received)
      transition(:created, from: :received, to: :created)
      transition(:stopped, from: :created, to: :stopped)
      transition(:running, from: :stopped, to: :running)
      transition(:errored, from: :*, to: :error)
    end
  end

  graphql do
    type :container_deployment
  end

  actions do
    defaults [:read, :destroy]

    create :deploy do
      description """
      Deploys an image on a device, the status according to device triggers.
      """

      accept [:container_id]

      argument :device_id, :id do
        allow_nil? false
      end

      change manage_relationship(:device_id, :device, type: :append)
      change Changes.DeployContainerOnDevice
      change transition_state(:sent)
    end

    update :received do
      change transition_state(:received)
    end

    update :created do
      change transition_state(:created)
    end

    update :stopped do
      change transition_state(:stopped)
    end

    update :running do
      change transition_state(:running)
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

    timestamps()
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Container do
      attribute_type :uuid
      public? true
    end

    belongs_to :device, Edgehog.Devices.Device
  end

  identities do
    identity :container_instance, [:container_id, :device_id]
  end

  postgres do
    table "container_deployments"

    references do
      reference :container, on_delete: :delete
      reference :device, on_delete: :delete
    end
  end
end
