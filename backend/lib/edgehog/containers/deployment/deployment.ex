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
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.Containers.Deployment.Calculations
  alias Edgehog.Containers.Deployment.Changes
  alias Edgehog.Containers.Deployment.Types.DeploymentState
  alias Edgehog.Containers.Deployment.Validations
  alias Edgehog.Containers.ManualActions
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Validations.IsUpgrade
  alias Edgehog.Containers.Validations.SameApplication

  @testing Mix.env() == :test

  graphql do
    type :deployment

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

      manual {ManualActions.SendDeploymentCommand, command: :start}
    end

    update :stop do
      description """
      Sends a :stop command to the release on the device.
      """

      validate Validations.IsReady

      manual {ManualActions.SendDeploymentCommand, command: :stop}
    end

    update :delete do
      description """
      Sends a :delete command to the release on the device.
      """

      validate Validations.IsReady

      manual {ManualActions.SendDeploymentCommand, command: :delete}
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

      change Changes.SendDeploymentToDevice
    end

    update :upgrade_release do
      argument :target, :uuid do
        allow_nil? false
      end

      validate Validations.IsReady

      validate SameApplication
      validate IsUpgrade

      manual ManualActions.SendDeploymentUpgrade
    end

    update :mark_as_sent do
      change set_attribute(:state, :sent)

      require_atomic? false
    end

    update :mark_as_started do
      change set_attribute(:state, :started)

      require_atomic? false
    end

    update :mark_as_stopped do
      change set_attribute(:state, :stopped)

      require_atomic? false
    end

    update :mark_as_timed_out do
      change set_attribute(:timed_out, true)

      require_atomic? false
    end

    update :append_event do
      require_atomic? false

      argument :event, :map do
        allow_nil? false
      end

      change Changes.AppendEvent
    end

    update :maybe_run_ready_actions do
      change Changes.MaybeRunReadyActions
      change Changes.MaybePublishDeploymentReady

      require_atomic? false
    end

    read :filter_by_release do
      argument :release_id, :uuid

      filter expr(release_id == ^arg(:release_id))
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
  end

  calculations do
    calculate :is_ready, :boolean, Calculations.Ready do
      public? true
    end
  end

  identities do
    identity :release_instance, [:device_id, :release_id]
  end

  pub_sub do
    prefix "deployments"
    module EdgehogWeb.Endpoint

    publish :deploy, [[:id, "*"]]
    publish :just_create, [[:id, "*"]]

    publish :mark_as_sent, [[:id, "*"]]
    publish :mark_as_started, [[:id, "*"]]
    publish :mark_as_stopped, [[:id, "*"]]
    publish :mark_as_timed_out, [[:id, "*"]]
    publish :append_event, [[:id, "*"]]
    publish :maybe_run_ready_actions, [[:id, "*"]]

    transform fn notification ->
      deployment = notification.data
      action = notification.action.name

      event_type =
        cond do
          Map.get(notification.metadata || %{}, :custom_event) == :deployment_ready ->
            :deployment_ready

          action in [:deploy, :just_create] ->
            :deployment_created

          action in [
            :mark_as_sent,
            :mark_as_started,
            :mark_as_stopped,
            :append_event,
            :maybe_run_ready_actions
          ] ->
            :deployment_updated

          action in [
            :mark_as_timed_out
          ] ->
            :deployment_timeout

          true ->
            :unknown_event
        end

      {event_type, deployment}
    end
  end

  postgres do
    table "application_deployments"

    references do
      reference :device, on_delete: :delete
    end
  end
end
