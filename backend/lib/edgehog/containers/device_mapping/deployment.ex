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

defmodule Edgehog.Containers.DeviceMapping.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.DeviceMapping.Changes
  alias Edgehog.Devices.Device

  graphql do
    type :device_mapping_deployment
  end

  actions do
    defaults [:read, :destroy, create: [:device_mapping_id, :device_id, :state]]

    create :deploy do
      description """
      Deploys a device-file mapping on a device.
      """

      argument :device_mapping, :struct do
        constraints instance_of: DeviceMapping
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
      change manage_relationship(:device, type: :append)
      change manage_relationship(:device_mapping, type: :append)
      change Changes.DeployDeviceMappingOnDevice
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_present do
      change set_attribute(:state, :present)
    end

    update :mark_as_not_present do
      change set_attribute(:state, :not_present)
    end

    update :mark_as_errored do
      argument :message, :string do
        allow_nil? false
      end

      change set_attribute(:last_message, arg(:message))
      change set_attribute(:state, :error)
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
    belongs_to :device_mapping, DeviceMapping do
      attribute_type :uuid
    end

    belongs_to :device, Device
  end

  calculations do
    calculate :ready?, :boolean, expr(state in [:present, :not_present])
  end

  identities do
    identity :device_mapping_instance, [:device_mapping_id, :device_id]
  end

  postgres do
    table "device_mapping_deployments"
    repo Edgehog.Repo

    references do
      reference :device_mapping, on_delete: :delete
      reference :device, on_delete: :delete
    end
  end
end
