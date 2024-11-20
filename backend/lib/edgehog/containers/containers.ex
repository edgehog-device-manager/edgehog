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

defmodule Edgehog.Containers do
  @moduledoc false
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  alias Edgehog.Containers.Application
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.ImageCredentials
  alias Edgehog.Containers.Release

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

      create Deployment, :deploy_release, :deploy do
        description "Deploy the application on a device"
        relay_id_translations input: [release_id: :release, device_id: :device]
      end

      update Deployment, :start_deployment, :start
      update Deployment, :stop_deployment, :stop
      update Deployment, :delete_deployment, :delete
    end
  end

  resources do
    resource Edgehog.Containers.Application

    resource Edgehog.Containers.Container do
      define :fetch_container, action: :read, get_by: [:id]
    end

    resource Edgehog.Containers.Deployment do
      define :deploy, action: :deploy, args: [:release_id, :device_id]
      define :send_deploy_request, action: :send_deploy_request, args: [:deployment]
      define :fetch_deployment, action: :read, get_by: [:id]
      define :deployment_set_status, action: :set_status, args: [:status, :message]

      define :delete_deployment, action: :destroy
    end

    resource Edgehog.Containers.Image do
      define :fetch_image, action: :read, get_by: [:id]
    end

    resource Edgehog.Containers.ImageCredentials

    resource Edgehog.Containers.Release do
      define :fetch_release, action: :read, get_by: [:id]
    end

    resource Edgehog.Containers.ReleaseContainers
    resource Edgehog.Containers.Network
    resource Edgehog.Containers.Volume
    resource Edgehog.Containers.ContainerNetwork
  end
end
