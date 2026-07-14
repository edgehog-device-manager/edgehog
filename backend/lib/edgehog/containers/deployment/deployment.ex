#
# This file is part of Edgehog.
#
# Copyright 2024 - 2026 SECO Mind Srl
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
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.Containers.Deployment.Calculations
  alias Edgehog.Containers.Deployment.Changes
  alias Edgehog.Containers.Deployment.Types.DeploymentContext
  alias Edgehog.Containers.Deployment.Types.DeploymentState
  alias Edgehog.Containers.Deployment.Validations
  alias Edgehog.Containers.ManualActions
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Validations.IsUpgrade
  alias Edgehog.Containers.Validations.SameApplication

  @testing Mix.env() == :test

  graphql do
    type :deployment

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :deployment do
        action_types [:create, :update, :destroy]
      end

      subscribe :deployment_by_id do
        action_types [:create, :update, :destroy]
        read_action :read_by_deployment_id
        relay_id_translations deployment_id: :deployment
      end

      subscribe :deployments_by_device do
        action_types [:create, :update, :destroy]
        read_action :read_by_device
        relay_id_translations device_id: :device
      end
    end

    paginate_relationship_with container_deployments: :relay, events: :relay
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:device_id, :release_id, :state]
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

      validate Validations.DeviceIsCompatible

      change manage_relationship(:device_id, :device, type: :append)
      change Changes.Relate
      change Changes.SendRequest
    end

    create :just_create do
      description """
      Starts the deployment of a release on a device.
      It starts an Executor, handling the communication with the device.
      """

      accept [:release_id]

      argument :device_id, :id do
        allow_nil? false
      end

      validate Validations.DeviceIsCompatible

      change manage_relationship(:device_id, :device, type: :append)
      change Changes.Relate
    end

    if @testing do
      create :create_fixture do
        description """
        Starts the deployment of a release on a device.
        It starts an Executor, handling the communication with the device.
        """

        accept [:release_id, :state]

        argument :device_id, :id do
          allow_nil? false
        end

        change manage_relationship(:device_id, :device, type: :append)
        change Changes.Relate
      end
    end

    update :set_state do
      accept [:state]
    end

    update :start do
      description """
      Sends a :start command to the release on the device.
      """

      validate Validations.IsReady
      validate {Validations.NoConflictingCampaign, action_type: :deployment_start}

      change set_attribute(:context, :start_message_sent)
      change {Edgehog.Changes.Log, message: "Deployment start message sent."}

      change {Changes.SendCommand, command: :start}
      require_atomic? false
    end

    update :stop do
      description """
      Sends a :stop command to the release on the device.
      """

      validate Validations.IsReady
      validate {Validations.NoConflictingCampaign, action_type: :deployment_stop}

      change set_attribute(:context, :stop_message_sent)
      change {Edgehog.Changes.Log, message: "Deployment stop message sent."}

      change {Changes.SendCommand, command: :stop}
      require_atomic? false
    end

    update :delete do
      description """
      Sends a :delete command to the release on the device.
      """

      validate Validations.IsReady
      validate {Validations.NoConflictingCampaign, action_type: :deployment_delete}

      change set_attribute(:context, :delete_message_sent)
      change {Edgehog.Changes.Log, message: "Deployment delete message sent."}

      change {Changes.SendCommand, command: :delete}
      require_atomic? false
    end

    update :run_ready_actions do
      description """
      Executes deployment callbacks
      """

      manual ManualActions.RunReadyActions
    end

    update :send_deployment do
      description """
      Sends the deployment to the device.
      Deploys the necessary resources and sends the deployment request.
      """

      require_atomic? false

      validate {Validations.IsReady, [readiness: false]}
      change Changes.SendDeploymentToDevice
    end

    update :retry_deployment do
      description """
      Sends the deployment to the device.
      Deploys the necessary resources and sends the deployment request.
      """

      require_atomic? false

      validate {Validations.IsReady, [readiness: false]}
      change Changes.SendDeploymentToDevice
      change Changes.Reconcile
    end

    update :upgrade_release do
      argument :target, :uuid do
        allow_nil? false
      end

      validate Validations.IsReady
      validate {Validations.NoConflictingCampaign, action_type: :deployment_upgrade}

      validate SameApplication
      validate IsUpgrade

      change {Edgehog.Changes.Log, message: "Deployment upgrade message sent."}

      change set_attribute(:context, :upgrade_message_sent)

      change Changes.SendUpgrade
      require_atomic? false
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)
    end

    update :mark_as_started do
      change set_attribute(:state, :started)
      change set_attribute(:context, nil)

      change Changes.LogStarted
      require_atomic? false
    end

    update :mark_as_stopped do
      change set_attribute(:state, :stopped)
      change set_attribute(:context, nil)

      change Changes.LogStopped
      require_atomic? false
    end

    update :mark_as_timed_out do
      change set_attribute(:timed_out, true)
    end

    update :append_event do
      require_atomic? false

      argument :event, :map do
        allow_nil? false
      end

      change {Edgehog.Changes.Log, message: "Deployment could not be started."} do
        where [
          data_one_of(:context, [:start_message_sent]),
          {Validations.Event, type: "Error"}
        ]
      end

      change {Edgehog.Changes.Log, message: "Deployment could not be stopped."} do
        where [
          data_one_of(:context, [:stop_message_sent]),
          {Validations.Event, type: "Error"}
        ]
      end

      change {Edgehog.Changes.Log, message: "Deployment deletion failed."} do
        where [
          data_one_of(:context, [:delete_message_sent]),
          {Validations.Event, type: "Error"}
        ]
      end

      change {Edgehog.Changes.Log, message: "Deployment upgrade failed."} do
        where [
          data_one_of(:context, [:upgrade_message_sent]),
          {Validations.Event, type: "Error"}
        ]
      end

      change {Edgehog.Changes.Log, message: "Deployment provisioning failed."} do
        where [
          data_one_of(:state, [:pending, :sent]),
          {Validations.Event, type: "Error"}
        ]
      end

      change Changes.AppendEvent
    end

    read :filter_by_release do
      argument :release_id, :uuid

      filter expr(release_id == ^arg(:release_id))
    end

    read :read_by_deployment_id do
      argument :deployment_id, :uuid, allow_nil?: false
      get? true

      filter expr(id == ^arg(:deployment_id))
    end

    read :read_by_device do
      argument :device_id, :id, allow_nil?: false

      get_by :device_id
    end

    destroy :destroy_and_gc do
      require_atomic? false
      change {Edgehog.Containers.Changes.MaybeDestroyChildren, children: [:container_deployments]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :state, DeploymentState do
      default :pending
      public? true
    end

    attribute :context, DeploymentContext do
      default nil
    end

    attribute :timed_out, :boolean do
      allow_nil? false
      default false
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

    many_to_many :container_deployments, Edgehog.Containers.Container.Deployment do
      through Edgehog.Containers.DeploymentContainerDeployment
      source_attribute_on_join_resource :deployment_id
      destination_attribute_on_join_resource :container_deployment_id
      public? true
    end

    has_many :events, Edgehog.Containers.Deployment.Event do
      public? true
    end

    has_one :campaign_target, Edgehog.Campaigns.CampaignTarget do
      description """
      The deployment target of a deployment campaign that created this deployment.
      Only returns targets for deploy and upgrade operation campaigns.
      Returns nil for other operation types (start, stop, delete).
      """

      public? true

      # Filter to only include deploy and upgrade operation types
      filter expr(campaign.campaign_mechanism[:type] in [:deployment_deploy, :deployment_upgrade])
    end
  end

  calculations do
    calculate :is_ready, :boolean, Calculations.Ready do
      public? true
    end
  end

  identities do
    identity :release_instance, [:device_id, :release_id]
  end

  changes do
    change {Edgehog.Changes.Log, message: "Deployment provision started."},
      on: :create

    change {Edgehog.Changes.Log, message: "Deployment deleted successfully."},
      on: :destroy
  end

  pub_sub do
    prefix "deployments"
    module EdgehogWeb.Endpoint

    publish :deploy, [[:id, "*"]]
    publish :just_create, [[:id, "*"]]

    publish :set_state, [[:state, nil], [:id, "*"]]
    publish :mark_as_sent, [[:state, nil], [:id, "*"]]
    publish :mark_as_started, [[:state, nil], [:id, "*"]]
    publish :mark_as_stopped, [[:state, nil], [:id, "*"]]
    publish :mark_as_timed_out, [["timeout", nil], [:id, "*"]]
    publish :append_event, [[:id, "*"]]
    publish :destroy_and_gc, [[:id, "*"]]
  end

  postgres do
    table "application_deployments"

    references do
      reference :device, on_delete: :delete
    end
  end
end
