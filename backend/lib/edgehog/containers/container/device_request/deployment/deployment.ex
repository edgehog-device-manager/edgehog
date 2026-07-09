#
# This file is part of Edgehog.
#
# Copyright 2025-2026 SECO Mind Srl
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

defmodule Edgehog.Containers.DeviceRequest.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeviceRequest
  alias Edgehog.Containers.DeviceRequest.Deployment.Changes
  alias Edgehog.Containers.Validations
  alias Edgehog.Devices.Device

  graphql do
    type :device_request_deployment
  end

  actions do
    defaults [:read, :destroy, create: [:device_request_id, :device_id, :state]]

    create :deploy do
      description """
      Deploys a device request on a device.
      """

      argument :device_request, :struct do
        constraints instance_of: DeviceRequest
        allow_nil? false
      end

      argument :device, :struct do
        constraints instance_of: Device
        allow_nil? false
      end

      change set_attribute(:state, :created)
      change manage_relationship(:device, type: :append)
      change manage_relationship(:device_request, type: :append)
    end

    update :send_deployment do
      description """
      Sends the deployment to the device.
      """

      argument :deployment, :struct do
        constraints instance_of: Deployment
        allow_nil? false
      end

      require_atomic? false

      change Changes.DeployDeviceRequestOnDevice
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_present do
      require_atomic? false

      change set_attribute(:state, :present)
    end

    update :mark_as_not_present do
      require_atomic? false

      change set_attribute(:state, :not_present)
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
        one_of: [:created, :sent, :present, :not_present, :error]
      ],
      public?: true

    timestamps()
  end

  relationships do
    belongs_to :device_request, DeviceRequest do
      attribute_type :uuid
      public? true
    end

    belongs_to :device, Device

    many_to_many :container_deployments, Edgehog.Containers.Container.Deployment do
      through Edgehog.Containers.ContainerDeploymentDeviceRequestDeployment
      source_attribute_on_join_resource :device_request_deployment_id
      destination_attribute_on_join_resource :container_deployment_id
      public? true
    end
  end

  calculations do
    calculate :is_ready, :boolean, expr(state in [:present, :not_present]) do
      public? true
    end

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :container_deployments]}
  end

  identities do
    identity :device_request_instance, [:device_request_id, :device_id]
  end

  pub_sub do
    prefix "device_request_deployments"
    module EdgehogWeb.Endpoint

    publish :mark_as_present, [[:id, "*"]]
    publish :mark_as_not_present, [[:id, "*"]]
  end

  postgres do
    table "device_request_deployments"
    repo Edgehog.Repo

    references do
      reference :device_request, on_delete: :delete
      reference :device, on_delete: :delete
    end
  end
end
