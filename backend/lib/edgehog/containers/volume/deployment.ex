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

defmodule Edgehog.Containers.Volume.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Volume
  alias Edgehog.Containers.Volume.Changes
  alias Edgehog.Devices.Device

  graphql do
    type :volume_deployment
  end

  actions do
    defaults [:read, :destroy, create: [:volume_id, :device_id, :state]]

    create :deploy do
      description """
      Deploys an image on a device, the status according to device triggers.
      """

      argument :volume, :struct do
        constraints instance_of: Volume
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
      change manage_relationship(:volume, type: :append)
      change manage_relationship(:device, type: :append)
      change Changes.DeployVolumeOnDevice
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_available do
      change set_attribute(:state, :available)
    end

    update :mark_as_unavailable do
      change set_attribute(:state, :unavailable)
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
        one_of: [:created, :sent, :available, :unavailable, :error]
      ]

    timestamps()
  end

  relationships do
    belongs_to :volume, Edgehog.Containers.Volume do
      attribute_type :uuid
    end

    belongs_to :device, Edgehog.Devices.Device
  end

  calculations do
    calculate :ready?, :boolean, expr(state in [:available, :unavailable])
  end

  identities do
    identity :volume_instance, [:volume_id, :device_id]
  end

  postgres do
    table "application_volume_deployments"
  end
end
