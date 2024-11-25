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

defmodule Edgehog.Containers.Deployment do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Deployment.Changes
  alias Edgehog.Containers.ManualActions
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Types.DeploymentStatus
  alias Edgehog.Containers.Validations.IsUpgrade
  alias Edgehog.Containers.Validations.SameApplication

  graphql do
    type :deployment
  end

  actions do
    defaults [:read, :destroy, create: [:device_id, :release_id, :status, :message]]

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

    action :send_deploy_request do
      argument :deployment, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      run ManualActions.SendDeployRequest
    end

    update :upgrade_release do
      argument :target, :uuid do
        allow_nil? false
      end

      validate SameApplication
      validate IsUpgrade

      manual ManualActions.SendDeploymentUpgrade
    end

    update :set_status do
      accept [:status, :message]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, DeploymentStatus do
      public? true
    end

    attribute :message, :string do
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
  end

  identities do
    identity :release_instance, [:device_id, :release_id]
  end

  postgres do
    table "application_deployments"
  end
end
