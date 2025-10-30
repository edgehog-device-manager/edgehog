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

defmodule Edgehog.Containers.Network.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Changes.MaybeNotifyUpwards
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Network.Deployment.Changes
  alias Edgehog.Containers.Validations
  alias Edgehog.Devices.Device

  graphql do
    type :network_deployment
  end

  actions do
    defaults [:read, :destroy, create: [:network_id, :device_id, :state]]

    create :deploy do
      description """
      Deploys a network on a device.
      """

      argument :network, :struct do
        constraints instance_of: Network
        allow_nil? false
      end

      argument :device, :struct do
        constraints instance_of: Device
        allow_nil? false
      end

      change set_attribute(:state, :created)
      change manage_relationship(:device, type: :append)
      change manage_relationship(:network, type: :append)
    end

    update :send_deployment do
      description """
      Sends the deployment to the device.
      Deploys the necessary resources and sends the deployment request.
      """

      argument :deployment, :struct do
        constraints instance_of: Deployment
        allow_nil? false
      end

      require_atomic? false

      change Changes.DeployNetworkOnDevice
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_available do
      require_atomic? false
      change set_attribute(:state, :available)
      change MaybeNotifyUpwards
    end

    update :mark_as_unavailable do
      require_atomic? false
      change set_attribute(:state, :unavailable)
      change MaybeNotifyUpwards
    end

    update :mark_as_errored do
      argument :message, :string do
        allow_nil? false
      end

      change set_attribute(:last_message, arg(:message))
      change set_attribute(:state, :error)
    end

    destroy :destroy_if_dangling do
      require_atomic? false
      validate Validations.Dangling
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :last_message, :string

    attribute :state, :atom,
      constraints: [
        one_of: [:created, :sent, :available, :unavailable, :error]
      ],
      public?: true

    timestamps()
  end

  relationships do
    belongs_to :network, Network do
      attribute_type :uuid
    end

    belongs_to :device, Device

    many_to_many :container_deployments, Edgehog.Containers.Container.Deployment do
      through Edgehog.Containers.ContainerDeploymentNetworkDeployment
      source_attribute_on_join_resource :network_deployment_id
      destination_attribute_on_join_resource :container_deployment_id
      public? true
    end
  end

  calculations do
    calculate :is_ready, :boolean, expr(state in [:available, :unavailable])

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :container_deployments]}
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
