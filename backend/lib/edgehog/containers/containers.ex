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
    extensions: [AshGraphql.Domain]

  alias Edgehog.Containers.Application
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeploymentContainerDeployment
  alias Edgehog.Containers.DeploymentReadyAction
  alias Edgehog.Containers.DeploymentReadyAction.Upgrade
  alias Edgehog.Containers.ImageCredentials
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Volume

  graphql do
    root_level_errors? true

    queries do
      list Application, :applications, :read do
        description "Returns all the available applications."
        paginate_with :keyset
        relay? true
      end

      get ImageCredentials, :image_credentials, :read do
        description "Returns the desired image credentials."
      end

      list ImageCredentials, :list_image_credentials, :read do
        description "Returns all available image credentials."
        paginate_with :keyset
        relay? true
      end

      get Application, :application, :read do
        description "Returns the desired application."
      end

      get Release, :release, :read do
        description "Returns the desired release."
      end

      get Volume, :volume, :read do
        description "Returns the desired volume."
      end

      list Volume, :volumes, :read do
        description "Returns all available volumes."
        paginate_with :keyset
        relay? true
      end

      get Network, :network, :read do
        description "Returns the desired network."
      end

      list Network, :networks, :read do
        description "Returns all available networks."
        paginate_with :keyset
        relay? true
      end

      list Deployment, :deployments, :read do
        description "Returns all available dpeloyments."
        paginate_with :keyset
        relay? true
      end

      get Deployment, :deployment, :read do
        description "Returns the desired deployment."
      end
    end

    mutations do
      create Application, :create_application, :create do
        description "Create a new application."

        relay_id_translations input: [
                                initial_release: [
                                  containers: [
                                    image: [image_credentials_id: :image_credentials],
                                    networks: [
                                      id: :network
                                    ],
                                    volumes: [
                                      id: :volume
                                    ]
                                  ],
                                  required_system_models: [
                                    id: :system_model
                                  ]
                                ]
                              ]
      end

      destroy Application, :delete_application, :destroy

      create Release, :create_release, :create do
        description "Create a new release."

        relay_id_translations input: [
                                application_id: :application,
                                containers: [
                                  image: [
                                    image_credentials_id: :image_credentials
                                  ],
                                  networks: [
                                    id: :network
                                  ],
                                  volumes: [
                                    id: :volume
                                  ]
                                ],
                                required_system_models: [
                                  id: :system_model
                                ]
                              ]
      end

      create ImageCredentials, :create_image_credentials, :create do
        description "Create image credentials."
      end

      destroy ImageCredentials, :delete_image_credentials, :destroy

      create Volume, :create_volume, :create do
        description "Create a new volume."
      end

      destroy Volume, :delete_volume, :destroy do
        description "Delete a volume if not used by any container."
      end

      create Network, :create_network, :create do
        description "Create a new network."
      end

      destroy Network, :delete_network, :destroy do
        description "Delete a network if not used by any container."
      end

      create Deployment, :deploy_release, :deploy do
        description "Deploy the application on a device"
        relay_id_translations input: [release_id: :release, device_id: :device]
      end

      update Deployment, :start_deployment, :start
      update Deployment, :stop_deployment, :stop
      update Deployment, :delete_deployment, :delete
      update Deployment, :send_deployment, :send_deployment

      update Deployment, :upgrade_deployment, :upgrade_release do
        relay_id_translations input: [target: :release]
      end

      destroy Release, :delete_release, :destroy do
        description "Delete a release and cleanup dangling resources"
      end
    end
  end

  resources do
    resource Edgehog.Containers.Application

    resource Edgehog.Containers.Container do
      define :fetch_container, action: :read, get_by: [:id]
      define :containers_with_image, action: :filter_by_image, args: [:image_id]
      define :destroy_container_if_dangling, action: :destroy_if_dangling
    end

    resource Edgehog.Containers.Container.Deployment do
      define :deploy_container, action: :deploy, args: [:container, :device]
      define :destroy_container_deployment, action: :destroy
      define :fetch_container_deployment, action: :read, get_by_identity: :container_instance
      define :mark_container_deployment_as_sent, action: :mark_as_sent
      define :mark_container_deployment_as_received, action: :mark_as_received
      define :mark_container_deployment_as_created, action: :mark_as_created
      define :mark_container_deployment_as_stopped, action: :mark_as_stopped
      define :mark_container_deployment_as_running, action: :mark_as_running
      define :mark_container_deployment_as_errored, action: :mark_as_errored, args: [:message]
    end

    resource Edgehog.Containers.Deployment do
      define :deploy, action: :deploy, args: [:release_id, :device_id]
      define :destroy_deployment, action: :destroy
      define :fetch_deployment, action: :read, get_by: [:id]
      define :delete_deployment, action: :destroy
      define :deployment_update_resources_state, action: :maybe_run_ready_actions
      define :deployments_with_release, action: :filter_by_release, args: [:release_id]
      define :deployment_by_identity, action: :read, get_by_identity: :release_instance
      define :run_ready_actions, action: :run_ready_actions
      define :set_deployment_state, action: :set_state
      define :send_deployment, action: :send_deployment
      define :append_deployment_event, action: :append_event

      define :mark_deployment_as_sent, action: :mark_as_sent
      define :mark_deployment_as_started, action: :mark_as_started
      define :mark_deployment_as_stopped, action: :mark_as_stopped
      define :mark_deployment_as_timed_out, action: :mark_as_timed_out
    end

    resource Edgehog.Containers.Deployment.Event

    resource Edgehog.Containers.Image do
      define :fetch_image, action: :read, get_by: [:id]
      define :destroy_image_if_dangling, action: :destroy_if_dangling
    end

    resource Edgehog.Containers.Image.Deployment do
      define :deploy_image, action: :deploy, args: [:image, :device]
      define :destroy_image_deployment, action: :destroy
      define :fetch_image_deployment, action: :read, get_by_identity: :image_instance
      define :mark_image_deployment_as_sent, action: :mark_as_sent
      define :mark_image_deployment_as_unpulled, action: :mark_as_unpulled
      define :mark_image_deployment_as_pulled, action: :mark_as_pulled
      define :mark_image_deployment_as_errored, action: :mark_as_errored, args: [:message]
    end

    resource Edgehog.Containers.ImageCredentials

    resource Edgehog.Containers.Release do
      define :fetch_release, action: :read, get_by: [:id]
      define :delete_release, action: :destroy
    end

    resource Edgehog.Containers.ReleaseContainers do
      define :releases_with_container,
        action: :releases_by_container,
        args: [:container_id]
    end

    resource Edgehog.Containers.ReleaseSystemModel

    resource Edgehog.Containers.Network

    resource Edgehog.Containers.Network.Deployment do
      define :deploy_network, action: :deploy, args: [:network, :device]
      define :destroy_network_deployment, action: :destroy
      define :fetch_network_deployment, action: :read, get_by_identity: :network_instance
      define :mark_network_deployment_as_sent, action: :mark_as_sent
      define :mark_network_deployment_as_available, action: :mark_as_available
      define :mark_network_deployment_as_unavailable, action: :mark_as_unavailable
      define :mark_network_deployment_as_errored, action: :mark_as_errored, args: [:message]
    end

    resource Edgehog.Containers.ContainerDeploymentNetworkDeployment

    resource Edgehog.Containers.Volume

    resource Edgehog.Containers.Volume.Deployment do
      define :deploy_volume, action: :deploy, args: [:volume, :device]
      define :destroy_volume_deployment, action: :destroy
      define :fetch_volume_deployment, action: :read, get_by_identity: :volume_instance
      define :mark_volume_deployment_as_sent, action: :mark_as_sent
      define :mark_volume_deployment_as_available, action: :mark_as_available
      define :mark_volume_deployment_as_unavailable, action: :mark_as_unavailable
      define :mark_volume_deployment_as_errored, action: :mark_as_errored, args: [:message]
    end

    resource Edgehog.Containers.ContainerDeploymentVolumeDeployment

    resource Edgehog.Containers.DeviceMapping

    resource Edgehog.Containers.DeviceMapping.Deployment do
      define :deploy_device_mapping,
        action: :deploy,
        args: [:device_mapping, :device]

      define :destroy_device_mapping_deployment, action: :destroy

      define :fetch_device_mapping_deployment,
        action: :read,
        get_by_identity: :device_mapping_instance

      define :mark_device_mapping_deployment_as_sent, action: :mark_as_sent
      define :mark_device_mapping_deployment_as_present, action: :mark_as_present
      define :mark_device_mapping_deployment_as_not_present, action: :mark_as_not_present

      define :mark_device_mapping_deployment_as_errored,
        action: :mark_as_errored,
        args: [:message]
    end

    resource Edgehog.Containers.ContainerDeploymentDeviceMappingDeployment

    resource DeploymentContainerDeployment

    resource DeploymentReadyAction
    resource Upgrade

    resource Edgehog.Containers.ContainerNetwork do
      define :containers_with_network,
        action: :containers_by_network,
        args: [:network_id]
    end

    resource Edgehog.Containers.ContainerVolume do
      define :containers_with_volume,
        action: :containers_by_volume,
        args: [:volume_id]
    end

    resource DeploymentReadyAction do
      define :run_ready_action, action: :run
    end

    resource Upgrade
    resource DeploymentContainerDeployment
  end
end
