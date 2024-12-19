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

defmodule Edgehog.Containers.Image.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource, AshStateMachine]

  alias Edgehog.Containers.Image.Deployment.ExecutorSupervisor

  state_machine do
    initial_states([:created, :sent])
    default_initial_state(:created)

    transitions do
      transition(:unpulled, from: [:sent, :pulled], to: [:unpulled])
      transition(:pulled, from: :unpulled, to: [:pulled])
      transition(:errored, from: [:*], to: [:error])
    end
  end

  graphql do
    type :image_deployment
  end

  actions do
    defaults [:read, :destroy]

    create :deploy do
      description """
      Deploys an image on a device, the status according to device triggers.
      """

      accept [:image_id]

      argument :device_id, :id do
        allow_nil? false
      end

      change transition_state(:created)
      change manage_relationship(:device_id, :device, type: :append)

      change after_transaction(fn _changeset, result, _context ->
               with {:ok, deployment} <- result do
                 # Start the executor for the deployment only if the transaction succeeds
                 ExecutorSupervisor.start_executor!(deployment)
               end
             end)
    end

    update :sent do
      change transition_state(:sent)
    end

    update :unpulled do
      change transition_state(:unpulled)
    end

    update :pulled do
      change transition_state(:pulled)
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
    belongs_to :image, Edgehog.Containers.Image do
      attribute_type :uuid
      public? true
    end

    belongs_to :device, Edgehog.Devices.Device
  end

  identities do
    identity :image_instance, [:image_id, :device_id]
  end

  postgres do
    table "image_deployments"

    references do
      reference :image, on_delete: :delete
      reference :device, on_delete: :delete
    end
  end
end
