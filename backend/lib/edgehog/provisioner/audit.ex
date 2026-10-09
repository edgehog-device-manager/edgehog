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

defmodule Edgehog.Provisioner.Audit do
  @moduledoc """
  Convenience module for `Edgehog.Provisioner.Audit.Behaviour`.

  The resource specific observability functions required by the provisioner
  (logging and/or telemetry for each provisioning event) are not provided by
  this module: each `Audit` module nested inside a provisioner implements them
  explicitly, with the details specific to the resource it provisions.

  To use it, it is sufficient to add a using statement like so:

  ```ex
  defmodule ResourceDeploymentProvisioner do
    use Edgehog.Provisioner,
      resource: Edgehog.Containers.Resource.Deployment,
      core: Core,
      audit: Audit
  end

  defmodule Audit do
    use Edgehog.Provisioner.Audit
  end
  ```

  which will declare that the module implements
  `Edgehog.Provisioner.Audit.Behaviour`.
  """

  alias Ash.Resource.Info
  alias Edgehog.Provisioner.Audit

  defmacro __using__(_opts) do
    quote do
      @behaviour Audit.Behaviour

      require Logger

      @impl Audit.Behaviour
      def subscribing_to_events(topic) do
        Logger.debug("Subscribing to events on #{topic}")
      end

      @impl Audit.Behaviour
      def device_status(device_id, device_online?) do
        status = if device_online?, do: "online", else: "offline"

        Logger.debug("Device #{device_id} is currently #{status}")
      end

      @impl Audit.Behaviour
      def provisioning_started(%{id: id} = resource, _context) do
        name = Info.short_name(resource)

        Logger.debug("Provisioning started for resource #{id} of type #{inspect(name)}")
      end

      @impl Audit.Behaviour
      def sent_to_device(%{id: id} = resource, %{device_id: device_id} = _device) do
        name = Info.short_name(resource)

        Logger.debug("Resource #{id} of type #{inspect(name)} sent to the device #{device_id}")
      end

      @impl Audit.Behaviour
      def api_error(%{id: id} = resource, error) do
        name = Info.short_name(resource)

        Logger.debug("Error #{inspect(error)} on resource #{id} of type #{inspect(name)}")
      end

      @impl Audit.Behaviour
      def provisioning_completed(%{id: id} = resource, _context, _started_at, _retries, _result) do
        name = Info.short_name(resource)

        Logger.debug("Provisioning successful for resource #{id} of type #{inspect(name)}")
      end

      @impl Audit.Behaviour
      def provisioning_failed(%{id: id} = resource, _context, _started_at, _retries, reason) do
        name = Info.short_name(resource)

        Logger.debug(
          "Provisioning failed for resource #{id} of type #{inspect(name)}, reason: #{inspect(reason)}"
        )
      end

      defoverridable Audit.Behaviour
    end
  end
end
