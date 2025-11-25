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

defmodule Edgehog.Containers.Image.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Changes.MaybeNotifyUpwards
  alias Edgehog.Containers.Container.Deployment
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Image.Deployment.Changes
  alias Edgehog.Containers.Validations
  alias Edgehog.Devices.Device

  graphql do
    type :image_deployment
  end

  actions do
    defaults [:read, :destroy, create: [:image_id, :device_id, :state]]

    create :deploy do
      description """
      Deploys an image on a device.
      """

      argument :image, :struct do
        constraints instance_of: Image
        allow_nil? false
      end

      argument :device, :struct do
        constraints instance_of: Device
        allow_nil? false
      end

      change set_attribute(:state, :created)
      change manage_relationship(:image, type: :append)
      change manage_relationship(:device, type: :append)
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

      change Changes.DeployImageOnDevice
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_unpulled do
      require_atomic? false

      change set_attribute(:state, :unpulled)
      change MaybeNotifyUpwards
    end

    update :mark_as_pulled do
      require_atomic? false

      change set_attribute(:state, :pulled)
      change MaybeNotifyUpwards
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
      change MaybeNotifyUpwards
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
        one_of: [:created, :sent, :pulled, :unpulled, :error]
      ],
      public?: true

    timestamps()
  end

  relationships do
    belongs_to :image, Image do
      public? true
      attribute_type :uuid
    end

    belongs_to :device, Device

    has_many :container_deployments, Edgehog.Containers.Container.Deployment do
      destination_attribute :image_deployment_id
    end
  end

  calculations do
    calculate :is_ready, :boolean, expr(state in [:pulled, :unpulled])

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :container_deployments]}
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
