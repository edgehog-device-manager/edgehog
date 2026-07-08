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

defmodule Edgehog.Containers.Registries do
  @moduledoc """
  Container registries.

  These registries act as points to collect and manage processes that handle the
  provisioning of resources to the device.
  """
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      {Registry, keys: :unique, name: Deployment.Supervisor.Registry},
      {Registry, keys: :unique, name: Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Container.Deployment.Supervisor.Registry},
      {Registry, keys: :unique, name: Container.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Image.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Network.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: DeviceMapping.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: Volume.Deployment.Provisioner.Registry},
      {Registry, keys: :unique, name: DeviceRequest.Deployment.Provisioner.Registry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
