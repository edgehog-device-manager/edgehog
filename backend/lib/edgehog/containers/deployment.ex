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
    domain: Edgehog.Containers

  alias Edgehog.Containers.Deployment.Changes.CreateDeploymentOnDevice
  alias Edgehog.Containers.Release
  alias Edgehog.Devices.Device

  actions do
    defaults [:read, :destroy, create: [:device_id, :release_id]]

    create :deploy do
      description """
      Starts the deployment of a release on a device.
      It starts an Executor, handling the communication with the device.
      """

      argument :release, :struct do
        constraints instance_of: Release
        allow_nil? false
      end

      argument :device, :struct do
        constraints instance_of: Device
        allow_nil? false
      end

      change CreateDeploymentOnDevice
    end
  end

  attributes do
    uuid_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :device, Device

    belongs_to :release, Release do
      attribute_type :uuid
    end
  end

  identities do
    identity :release_instance, [:device_id, :release_id]
  end

  postgres do
    table "application_deployments"
  end
end
