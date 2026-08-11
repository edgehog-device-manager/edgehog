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

defmodule Edgehog.Containers.Provisioner.Behaviour do
  @moduledoc """
  Behaviour describing the API of a Provisioner for a deployment.
  This module shouldn't be used directly. Rather, it's best to
  use `Edgehog.Containers.Provisioner`), i.e.:

  ```ex
  defmodule ResourceProvisioner do
    use Edgehog.Containers.Provisioner, resource: :resource_name
  end
  ```

  which will add the default implementation of a `Provisioner`.
  All of the functions of this behaviour are overridable.
  Note that a `Provisioner` is `GenServer`, so you can also override any of its
  callbacks, if you need.
  """

  alias Edgehog.Containers.Container.Deployment, as: ContainerDeployment
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeviceMapping.Deployment, as: DeviceMappingDeployment
  alias Edgehog.Containers.DeviceRequest.Deployment, as: DeviceRequestDeployment
  alias Edgehog.Containers.Image.Deployment, as: ImageDeployment
  alias Edgehog.Containers.Network.Deployment, as: NetworkDeployment
  alias Edgehog.Containers.Volume.Deployment, as: VolumeDeployment
  alias Edgehog.Tenants.Tenant

  @doc """
  Starts the right process through the correct (usually dynamic) supervisor.
  In he default implementation, when creating the link, the server checks a
  registry to know whether the corresponding process is already up and running.
  Check `start_link/1` docs for more info.
  """
  @callback provision(
              resource_deployment(),
              release_deployment(),
              Tenant.t() | pos_integer(),
              provision_opts()
            ) :: GenServer.on_start()

  @doc """
  Starts a provisioner for a resource deployment, linking the current process to
  the provisioner one.

  The default implementation for a provision for a resource follows the following flow:

  - checks that the resource is not ready already (i.e., the device never received it).
  - tries to send the deployment information to astarte (calling `&Devices.send_<resource_name>_deployment/2`)
  - if an unrecoverable error occurs, broadcasts a failure on the `topic/1` topic.
  - if successful, waits for events on the resource deployment itself.

  - if a trigger reaches edgehog, it changes a property in the resource deployment
    resource, emitting an event for the provsioner.
  - the provisioner understands that the resource is ready, so it exits successfully.

  - if the reconciler has no messages incoming after a timer defined through the
    `Core.timeout/1` function:
    + checks for readiness of the resource, maybe we just missed the message
    + queries astarte, maybe the trigger was missing
    + retries to send the message to the device.
    + loops with a new timeout set by the `Core.timeout/1` function.
  """
  @callback start_link(start_opts()) :: GenServer.on_start()

  @doc """
  Starts a provisioner for a resource deployment, without linking it to the
  current process.

  See `start_link/1` docs for more information.
  """
  @callback start(start_opts()) :: GenServer.on_start()

  @doc """
  Returns the via tuple used as the name for the provisioner on its registry.
  """
  @callback name(resource_deployment()) :: {:via, Registry, {provisioner_registry(), id()}}

  # TODO: add &topic/1 callback

  @typedoc """
  An `Ash.Resource.record()` belonging to the resource's deployment type.
  """
  @type resource_deployment() ::
          ImageDeployment.t()
          | NetworkDeployment.t()
          | VolumeDeployment.t()
          | DeviceMappingDeployment.t()
          | DeviceRequestDeployment.t()
          | ContainerDeployment.t()

  @typedoc """
  An `Ash.Resource.record()` belonging to the `Edgehog.Containers.Deployment` type.
  """
  @type release_deployment() :: Deployment.t()

  @type provision_opts() :: start_opts() | keyword()

  @type start_opts() :: [
          resource_deployment: resource_deployment(),
          deployment: release_deployment(),
          tenant: Tenant.t(),
          mode: :auto | :manual
        ]

  @typedoc """
  The state map of the provisioner.

  In the default implementation, it includes other key on top of the required ones:
  %{
    device_online?: boolean(),
    mode: :auto | :manual
  }
  """
  @type state() :: %{
          resource_deployment: resource_deployment(),
          deployment: release_deployment(),
          tenant: Tenant.t(),
          state: :init | :sent,
          retries: non_neg_integer()
        }

  @typedoc """
  A term, usually a module-like atom, identifying a registry for the provisioners
  """
  @type provisioner_registry() :: term()

  @type id() :: term()
end
