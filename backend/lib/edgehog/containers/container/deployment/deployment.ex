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

defmodule Edgehog.Containers.Container.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Container.Deployment.Calculations
  alias Edgehog.Containers.Container.Deployment.Changes
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Validations
  alias Edgehog.Devices.Device

  graphql do
    type :container_deployment

    paginate_relationship_with network_deployments: :relay,
                               volume_deployments: :relay,
                               device_mapping_deployments: :relay
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:container_id, :device_id, :image_deployment_id, :state]
    ]

    create :deploy do
      description """
      Deploys an image on a device, the status according to device triggers.
      """

      argument :container, :struct do
        constraints instance_of: Container
        allow_nil? false
      end

      argument :device, :struct do
        constraints instance_of: Device
        allow_nil? false
      end

      argument :deployment, :struct do
        constraints instance_of: Deployment
        allow_nil? false
      end

      change set_attribute(:state, :created)
      change manage_relationship(:container, type: :append)
      change manage_relationship(:device, type: :append)
      change Changes.Relate
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

      change Changes.DeployContainerOnDevice
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_received do
      change set_attribute(:state, :received)
    end

    update :mark_as_created do
      change set_attribute(:state, :device_created)
    end

    update :mark_as_stopped do
      change set_attribute(:state, :stopped)
    end

    update :mark_as_running do
      change set_attribute(:state, :running)
    end

    update :mark_as_errored do
      argument :message, :string do
        allow_nil? false
      end

      change set_attribute(:last_message, arg(:message))
      change set_attribute(:state, :error)
    end

    update :set_state do
      accept [:state]

      require_atomic? false
      change Changes.MaybeNotifyUpwards
    end

    update :maybe_notify_upwards do
      require_atomic? false
      change Changes.MaybeNotifyUpwards
    end

    destroy :destroy_if_dangling do
      require_atomic? false
      validate Validations.Dangling

      change {Edgehog.Containers.Changes.MaybeDestroyChildren,
              children: [
                :image_deployment,
                :volume_deployments,
                :network_deployments,
                :device_mapping_deployments
              ]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :last_message, :string

    attribute :state, :atom,
      constraints: [
        one_of: [:created, :sent, :received, :device_created, :stopped, :running, :error]
      ],
      public?: true

    timestamps()
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Container do
      attribute_type :uuid
      public? true
    end

    belongs_to :device, Edgehog.Devices.Device do
      public? true
    end

    many_to_many :deployments, Edgehog.Containers.Deployment do
      through Edgehog.Containers.DeploymentContainerDeployment
      source_attribute_on_join_resource :container_deployment_id
      destination_attribute_on_join_resource :deployment_id
    end

    belongs_to :image_deployment, Edgehog.Containers.Image.Deployment do
      attribute_type :uuid
      public? true
    end

    many_to_many :network_deployments, Edgehog.Containers.Network.Deployment do
      through Edgehog.Containers.ContainerDeploymentNetworkDeployment
      source_attribute_on_join_resource :container_deployment_id
      destination_attribute_on_join_resource :network_deployment_id
      public? true
    end

    many_to_many :volume_deployments, Edgehog.Containers.Volume.Deployment do
      through Edgehog.Containers.ContainerDeploymentVolumeDeployment
      source_attribute_on_join_resource :container_deployment_id
      destination_attribute_on_join_resource :volume_deployment_id
      public? true
    end

    many_to_many :device_mapping_deployments, Edgehog.Containers.DeviceMapping.Deployment do
      through Edgehog.Containers.ContainerDeploymentDeviceMappingDeployment
      source_attribute_on_join_resource :container_deployment_id
      destination_attribute_on_join_resource :device_mapping_deployment_id
      public? true
    end
  end

  calculations do
    calculate :is_ready, :boolean, Calculations.Ready

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :deployments]}
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
