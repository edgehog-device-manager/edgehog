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
  Behaviour describing the API of the Core functions for a deployment Provisioner.
  This module shouldn't be used directly. Rather, it's best to
  use `Edgehog.Containers.Provisioner.Core`), i.e.:

  ```ex
  defmodule ResourceProvisioner.Core do
    use Edgehog.Containers.Provisioner.Core
  end
  ```

  which will add the default implementation of `Provisioner.Core`.

  All of the functions of this behaviour are overridable.
  """

  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Provisioner
  alias Edgehog.Tenants.Tenant

  @doc """
  Sends the appropriate message to a device, extracting the required information
  from the provisioner state.

  By default, it returns a `{:noreply, state, timeout}` tuple for the provisioner,
  with the updated state and the timeout after which the send should be retried.
  """
  @callback send(state()) :: {:noreply, state(), timeout()}

  @doc """
  Sends the appropriate messages to the device.

  In the default implementation, it loads all the necessary data from the deployment,
  and then calls the correct `Edgehog.Devices.send_create_<resource_name>_request/4`
  function.
  """
  @callback send_to_device(resource_deployment(), keyword()) :: :ok | {:error, term()}

  @doc """
  Tries to reconcile the resource deployment with the property set by the device.

  In the default implementation, this function reads the available resources the
  device publishes, and either finds a state, and sets the resource deployment to
  that state or does not find a valid state, therefore the device does not have
  such resource deployed, and the function returns :not_found.

  Alternatively, if something went wrong while updating the resource, an
  `{:error, _}` is returned.

  Example:
  ```elixir
  Core.reconcile(resource_deployment, tenant: tenant)
  > {:ok, new_resource_deployment}

  Core.reconcile(resource_deployment, tenant: tenant)
  > :not_found
  ```
  """
  @callback reconcile(resource_deployment(), reconcile_opts()) :: ash_action_return() | :not_found

  @doc "Should be considered a **private** function, and not to be used directly."
  @callback __maybe_update__(
              resource_status_record(),
              resource_deployment(),
              Tenant.t()
            ) :: ash_action_return()

  @doc """
  Returns the timeout for retries.

  In the default implementation, it is an exponential backoff timeout:
  it reads information from the deployment state (current deployment state, and
  number of retries that happened), and it computes the timeout with the following
  formula

  ```
  timeout = pad + (2^retries) + rand(0,1000)
  timeout = min(timeout, max_timeout)
  ```

  - pad       :: the pad component is there to ensure a minimum timeout is
  guaranteed. The pad is only applied when the resource deployment
  has been sent, and therefore we're waiting for astarte triggers
  - 2^retries :: this is the exponential component, increases at each retry to
  ensure we don't DDoS astarte/the device.
  - rand      :: a random (between 0 and 1s) ensures no synchronization errors
  appear.
  """
  @callback timeout(state()) :: timeout()

  @doc """
  A function that returns the action to perform on a given resource
  deployment, based on the status returned by the corresponding Astarte interface.
  Should be considered **private**, and not to be used directly.
  """
  @callback __update_action__(resource_status_record()) :: mark_as_action_atom()

  @typedoc """
  An `Ash.Resource.record()` for a specific resource status, as returned by
  a `AvailableResource` Astarte interface
  """
  @type resource_status_record() :: Ash.Resource.record()

  @typedoc """
  The atom representing an update action for a resource deployment.
  It follows the form `:mark_as_*`.

  For example, image deployments are either `:mark_as_unpulled` or `:mark_as_pulled`.
  """
  @type mark_as_action_atom() :: atom()

  @type ash_action_return() ::
          {:ok, Ash.Resource.record()}
          | {:ok, Ash.Resource.record(), [Ash.Notifier.Notification.t()]}
          | {:error, term()}

  @typedoc """
  See `Edgehog.Containers.Provisioner.Behaviour.state()`.
  """
  @type state() :: Provisioner.Behaviour.state()

  @typedoc """
  See `Edgehog.Containers.Provisioner.Behaviour.resource_deployment()`.
  """
  @type resource_deployment() :: Provisioner.Behaviour.resource_deployment()

  @type reconcile_opts() :: [tenant: Tenant.t()]

  @type send_to_device_opts() :: [tenant: Tenant.t(), deployment: Deployment.t()]
end
