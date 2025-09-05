#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Deployment.Changes
  alias Edgehog.Containers.Deployment.Types.DeploymentState
  alias Edgehog.Containers.Deployment.Types.ResourcesState
  alias Edgehog.Containers.ManualActions
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Validations.IsUpgrade
  alias Edgehog.Containers.Validations.SameApplication

  graphql do
    type :deployment
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:device_id, :release_id, :state, :last_error_message, :resources_state]
    ]

    create :deploy do
      description """
      Starts the deployment of a release on a device.
      It starts an Executor, handling the communication with the device.
      """

      accept [:release_id]

      argument :device_id, :id do
        allow_nil? false
      end

      change manage_relationship(:device_id, :device, type: :append)

      change Changes.CreateDeploymentOnDevice
    end

    update :start do
      description """
      Sends a :start command to the release on the device.
      """

      manual {ManualActions.SendDeploymentCommand, command: :start}
    end

    update :stop do
      description """
      Sends a :stop command to the release on the device.
      """

      manual {ManualActions.SendDeploymentCommand, command: :stop}
    end

    update :delete do
      description """
      Sends a :delete command to the release on the device.
      """

      manual {ManualActions.SendDeploymentCommand, command: :delete}
    end

    update :run_ready_actions do
      description """
      Executes deployment callbacks
      """

      manual ManualActions.RunReadyActions
    end

    update :upgrade_release do
      argument :target, :uuid do
        allow_nil? false
      end

      validate SameApplication
      validate IsUpgrade

      manual ManualActions.SendDeploymentUpgrade
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_started do
      change set_attribute(:state, :started)
    end

    update :mark_as_starting do
      require_atomic? false

      change Changes.MarkAsStarting
    end

    update :mark_as_stopped do
      change set_attribute(:state, :stopped)
    end

    update :mark_as_stopping do
      require_atomic? false

      change Changes.MarkAsStopping
    end

    update :mark_as_errored do
      argument :message, :string do
        allow_nil? false
      end

      change set_attribute(:last_error_message, arg(:message))
      change set_attribute(:state, :error)
    end

    update :mark_as_deleting do
      change set_attribute(:state, :deleting)
    end

    update :update_resources_state do
      change Changes.CheckImages
      change Changes.CheckNetworks
      change Changes.CheckVolumes
      change Changes.CheckDeviceMappings
      change Changes.CheckContainers
      change Changes.CheckDeployment

      require_atomic? false
    end

    read :filter_by_release do
      argument :release_id, :uuid

      filter expr(release_id == ^arg(:release_id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :resources_state, ResourcesState do
      default :initial
      public? true
    end

    attribute :state, DeploymentState do
      default :created
      public? true
    end

    attribute :last_error_message, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Edgehog.Devices.Device do
      public? true
    end

    belongs_to :release, Release do
      attribute_type :uuid
      public? true
    end

    has_many :ready_actions, Edgehog.Containers.DeploymentReadyAction do
      public? true
    end
  end

  calculations do
    calculate :ready?, :boolean, expr(state in [:started, :starting, :stopped, :stopping])
    calculate :resources_ready?, :boolean, expr(resources_state == :ready)
  end

  identities do
    identity :release_instance, [:device_id, :release_id]
  end

  postgres do
    table "application_deployments"

    references do
      reference :device, on_delete: :delete
    end
  end
end
