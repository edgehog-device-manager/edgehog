#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Supervisor do
  @moduledoc """
  Container registries.

  These registries act as points to collect and manage processes that handle the
  provisioning of resources to the device.
  """
  use Supervisor

  alias Edgehog.Containers

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      # Registries
      {Registry, keys: :unique, name: Containers.Deployment.Orchestrator.Registry},
      {Registry, keys: :unique, name: Containers.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Containers.Container.Deployment.Orchestrator.Registry},
      {Registry, keys: :unique, name: Containers.Container.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Containers.Image.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Containers.Network.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Containers.DeviceMapping.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Containers.Volume.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Containers.DeviceRequest.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Containers.Deployment.Starter.Registry},

      # Supervisors
      {DynamicSupervisor,
       name: Containers.Deployment.Orchestrator.Supervisor, strategy: :one_for_one},
      {DynamicSupervisor,
       name: Containers.Container.Deployment.Orchestrator.Supervisor, strategy: :one_for_one},

      # Provisioners supervisors
      {DynamicSupervisor,
       name: Containers.Deployment.Provisioner.Supervisor, strategy: :one_for_one},
      {DynamicSupervisor,
       name: Containers.Container.Provisioner.Supervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: Containers.Image.Provisioner.Supervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: Containers.Volume.Provisioner.Supervisor, strategy: :one_for_one},
      {DynamicSupervisor,
       name: Containers.Network.Provisioner.Supervisor, strategy: :one_for_one},
      {DynamicSupervisor,
       name: Containers.DeviceMapping.Provisioner.Supervisor, strategy: :one_for_one},
      {DynamicSupervisor,
       name: Containers.DeviceRequest.Provisioner.Supervisor, strategy: :one_for_one},

      # Starter supervisor
      {DynamicSupervisor, name: Containers.Deployment.Starter.Supervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
