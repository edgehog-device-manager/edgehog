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

defmodule Edgehog.Containers do
  @moduledoc false
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  alias Edgehog.Containers.Application
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.ContainerNetwork
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.ImageCredentials
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.ReleaseContainers
  alias Edgehog.Containers.Volume

  graphql do
    root_level_errors? true

    queries do
      list Application, :applications, :read do
        description "Returns all the available applications."
      end

      get ImageCredentials, :image_credentials, :read do
        description "Returns the desired image credentials."
      end

      list ImageCredentials, :list_image_credentials, :read do
        description "Returns all available image credentials."
      end

      get Application, :application, :read do
        description "Returns the desired application."
      end

      get Release, :release, :read do
        description "Returns the desired release."
      end
    end

    mutations do
      create Application, :create_application, :create do
        description "Create a new application."
      end

      create Release, :create_release, :create do
        description "Create a new release."
        relay_id_translations input: [application_id: :application]
      end

      create ImageCredentials, :create_image_credentials, :create do
        description "Create image credentials."
      end

      destroy ImageCredentials, :delete_image_credentials, :destroy

      create Release.Deployment, :deploy_release, :deploy do
        description "Deploy the application on a device"
        relay_id_translations input: [release_id: :release, device_id: :device]
      end

      update Release.Deployment, :start_deployment, :start
      update Release.Deployment, :stop_deployment, :stop
      update Release.Deployment, :delete_deployment, :delete

      update Release.Deployment, :upgrade_deployment, :upgrade_release do
        relay_id_translations input: [target: :release]
      end
    end
  end

  resources do
    resource Application

    resource Container do
      define :fetch_container, action: :read, get_by: [:id]
      define :containers_with_image, action: :filter_by_image, args: [:image_id]
    end

    resource Container.Deployment do
      define :deploy_container, action: :deploy, args: [:container_id, :device_id]
      define :fetch_container_deployment, action: :read, get_by_identity: :container_instance
      define :container_deployment_sent, action: :sent
      define :container_deployment_received, action: :received
      define :container_deployment_created, action: :created
      define :container_deployment_stopped, action: :stopped
      define :container_deployment_running, action: :running
      define :container_deployment_errored, action: :errored, args: [:message]
    end

    resource Release do
      define :fetch_release, action: :read, get_by: [:id]
    end

    resource Release.Deployment do
      define :deploy, action: :deploy, args: [:release_id, :device_id]
      define :fetch_deployment, action: :read, get_by: [:id]

      define :delete_deployment, action: :destroy
      define :deployments_with_release, action: :filter_by_release, args: [:release_id]
      define :run_ready_actions, action: :run_ready_actions

      define :release_deployment_sent, action: :sent
      define :release_deployment_started, action: :started
      define :release_deployment_stopped, action: :stopped
      define :release_deployment_error, action: :error, args: [:message]

      define :release_deployment_starting, action: :starting
      define :release_deployment_stopping, action: :stopping
    end

    resource Release.Deployment.ReadyAction do
      define :run_ready_action, action: :run
    end

    resource Release.Deployment.ReadyAction.Upgrade

    resource Image do
      define :fetch_image, action: :read, get_by: [:id]
    end

    resource Image.Deployment do
      define :deploy_image, action: :deploy, args: [:image_id, :device_id]
      define :fetch_image_deployment, action: :read, get_by_identity: :image_instance
      define :image_deployment_sent, action: :sent
      define :image_deployment_unpulled, action: :unpulled
      define :image_deployment_pulled, action: :pulled
      define :image_deployment_errored, action: :errored, args: [:message]
    end

    resource ImageCredentials

    resource ReleaseContainers do
      define :releases_with_container,
        action: :releases_by_container,
        args: [:container_id]
    end

    resource Volume

    resource Volume.Deployment do
      define :deploy_volume, action: :deploy, args: [:volume_id, :device_id]
      define :fetch_volume_deployment, action: :read, get_by_identity: :volume_instance
      define :volume_deployment_sent, action: :sent
      define :volume_deployment_available, action: :available
      define :volume_deployment_unavailable, action: :unavailable
      define :volume_deployment_errored, action: :errored, args: [:message]
      define :volume_is_deployed?, action: :read, get_by_identity: :volume_instance
    end

    resource Network

    resource Network.Deployment do
      define :deploy_network, action: :deploy, args: [:network_id, :device_id]
      define :fetch_network_deployment, action: :read, get_by_identity: :network_instance
      define :network_deployment_sent, action: :sent
      define :network_deployment_available, action: :available
      define :network_deployment_unavailable, action: :unavailable
      define :network_deployment_errored, action: :errored, args: [:message]
      define :network_is_deployed?, action: :read, get_by_identity: :network_instance
    end

    resource ContainerNetwork do
      define :containers_with_network,
        action: :containers_by_network,
        args: [:network_id]
    end

    resource Edgehog.Containers.ContainerVolume
  end
end
