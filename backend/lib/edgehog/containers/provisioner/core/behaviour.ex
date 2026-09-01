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

defmodule Edgehog.Containers.Provisioner.Core.Behaviour do
  @moduledoc """
  Behaviour describing the API of the Core functions for a Provisioner.

  A `Core` module contains the resource specific functions required by the
  provisioner to perform the provisioning: pure functions that can be tested in
  isolation, and functions that provide the side effects of the provisioning
  flow (e.g. actually sending the request to the device, or reconciling the
  resource state with what astarte reports).

  This module shouldn't be used directly. Rather, it's best to
  use `Edgehog.Containers.Provisioner.Core`, i.e.:

  ```ex
  defmodule ResourceProvisioner.Core do
    use Edgehog.Containers.Provisioner.Core
  end
  ```

  which will declare that the module implements this behaviour. All the
  functions of this behaviour must be implemented explicitly: there are no
  default implementations.
  """

  alias Edgehog.Containers.Provisioner
  alias Edgehog.Tenants.Tenant

  @doc """
  Sends the appropriate messages to the device.

  It loads all the necessary data from the resource, and then calls the correct
  `Edgehog.Devices.send_create_<resource_name>_request/4` function.
  """
  @callback send_to_device(resource(), send_to_device_opts()) :: :ok | {:error, term()}

  @doc """
  Tries to reconcile the resource with the property set by the device.

  This function reads the available resources the device publishes, and either
  finds a state, and sets the resource to that state or does not find a valid
  state, therefore the device does not have such resource deployed, and the
  function returns :not_found.

  Alternatively, if something went wrong while updating the resource, an
  `{:error, _}` is returned.

  Example:
  ```elixir
  Core.reconcile(resource, tenant: tenant)
  > {:ok, new_resource}

  Core.reconcile(resource, tenant: tenant)
  > :not_found
  ```
  """
  @callback reconcile(resource(), reconcile_opts()) :: ash_action_return() | :not_found

  @doc """
  Checks whether the resource is in a terminal (ready) state, i.e. the device
  acknowledged its presence (or absence) and no further provisioning is needed.
  """
  @callback ready?(resource()) :: boolean()

  @doc """
  Logs when subscribing to resource events on the given topic.
  """
  @callback log_subscribing_to_events(String.t()) :: :ok

  @doc """
  Logs when subscribing to device status events.
  """
  @callback log_subscribing_to_device_status(String.t()) :: :ok

  @doc """
  Logs the current device online/offline status.
  """
  @callback log_device_status(String.t(), boolean()) :: :ok

  @doc """
  Logs when provisioning starts for a resource.

  Receives the actual resource that was sent and the device it was sent to.
  """
  @callback log_provisioning_started(resource(), resource()) :: :ok

  @doc """
  Logs when a send to device operation fails.
  """
  @callback log_api_error(resource(), error()) :: :ok

  @doc """
  Logs when provisioning fails for a resource.
  """
  @callback log_provisioning_failed(resource(), term()) :: :ok

  @doc """
  Logs when provisioning completes successfully for a resource.
  """
  @callback log_provisioning_completed(resource(), non_neg_integer()) :: :ok

  @doc """
  Returns the via tuple used as the name for the provisioner on its registry.
  """
  @callback name(resource()) :: {:via, Registry, {provisioner_registry(), id()}}

  @doc """
  Returns the topic onto which the provisioner broadcasts readiness and failure
  for the given resource.
  """
  @callback topic(resource()) :: String.t()

  @doc """
  Returns the topic onto which the provisioner subscribes to receive the events
  that the resource emits when it is updated.
  """
  @callback subscribe_topic(resource()) :: String.t()

  @doc """
  Checks whether an error returned by `send_to_device/3` from Astarte APIs is
  temporary (i.e.: can be retried in a bit), or if it's not, and should thus cause
  a failure of the Provisioner.
  """
  @callback temporary_error?(error()) :: boolean()

  @type ash_action_return() ::
          {:ok, Ash.Resource.record()}
          | {:ok, Ash.Resource.record(), [Ash.Notifier.Notification.t()]}
          | {:error, term()}

  @typedoc """
  See `Edgehog.Containers.Provisioner.Behaviour.resource()`.
  """
  @type resource() :: Provisioner.Behaviour.resource()

  @type reconcile_opts() :: [tenant: Tenant.t()]

  @type send_to_device_opts() :: [tenant: Tenant.t(), deployment: term()]

  @typedoc """
  A term, usually a module-like atom, identifying a registry for the provisioners
  """
  @type provisioner_registry() :: term()

  @type id() :: term()

  @type error() :: term()
end
