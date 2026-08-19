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

defmodule Edgehog.Containers.Provisioner.Core do
  @moduledoc """
  Convenience module for `Edgehog.Containers.Provisioner.Core.Behaviour`.

  The resource specific functions required by the provisioner (both the pure
  functions, e.g. `ready?/1` and `topic/1`, and the functions providing the
  side effects of the provisioning flow, e.g. `send_to_device/2` and
  `reconcile/2`) are not provided by this module: each `Core` module nested
  inside a provisioner implements them explicitly, with the details specific to
  the resource it provisions.

  To use it, it is sufficient to add a using statement like so:

  ```ex
  defmodule ResourceDeploymentProvisioner do
    use Edgehog.Containers.Provisioner, resource: Edgehog.Containers.Resource.Deployment, core: Core

    defmodule Core do
      use Edgehog.Containers.Provisioner.Core
    end
  end
  ```

  which will declare that the module implements
  `Edgehog.Containers.Provisioner.Core.Behaviour`.
  """

  defmacro __using__(_opts) do
    quote do
      alias Edgehog.Containers.Provisioner.Core

      @behaviour Core.Behaviour

      @impl Core.Behaviour
      def temporary_error?(error)

      def temporary_error?({:error, error}), do: temporary_error?(error)

      def temporary_error?(%{errors: errors}) when is_list(errors) and errors != [],
        do: Enum.any?(errors, &temporary_error?/1)

      def temporary_error?("connection refused"), do: true

      def temporary_error?(%Astarte.Client.APIError{status: status}) when status in 500..599,
        do: true

      def temporary_error?(%Edgehog.Error.AstarteAPIError{status: status})
          when status in 500..599, do: true

      def temporary_error?(%Edgehog.Error.DeviceOffline{}), do: true

      def temporary_error?(_error), do: false

      defoverridable temporary_error?: 1
    end
  end
end
