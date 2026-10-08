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

defmodule Edgehog.Provisioner.Audit.Behaviour do
  @moduledoc """
  Behavior describing the Audit functions for the Provisioner.

  `Audit` modules contain resource specific observability functions required by
  the provisioner. Each function handles a single provisioning event and
  chooses what to do (log and/or telemetry).

  This module shouldn't be used directyl, instead:

  ```ex
  defmodule ResourceProvisioner.Audit do
    use Edgehog.Provisioner.Audit
  end
  ```

  which will declare the module implements the behaviour.
  """

  alias Edgehog.Provisioner

  @doc """
  Audits the subscription to resource events on the given topic.
  """
  @callback subscribing_to_events(String.t()) :: term()

  @doc """
  Audits the current device online/offline status.
  """
  @callback device_status(String.t(), boolean()) :: term()

  @doc """
  Audits the start of a provisioning.

  Returns any state or metadata (e.g. start timestamp) needed for subsequent
  provisioning completed or failed events.
  """
  @callback provisioning_started(resource(), keyword()) :: term()

  @doc """
  Audits a successful send of the resource to the device.

  Receives the actual resource that was sent and the device it was sent to.
  """
  @callback sent_to_device(resource(), resource()) :: term()

  @doc """
  Audits a failed send to device operation.
  """
  @callback api_error(resource(), error()) :: term()

  @doc """
  Audits a successful provisioning.
  """
  @callback provisioning_completed(
              resource(),
              keyword(),
              start_metadata :: term(),
              retries :: non_neg_integer(),
              result :: term()
            ) :: term()

  @doc """
  Audits a failed provisioning.
  """
  @callback provisioning_failed(
              resource(),
              keyword(),
              start_metadata :: term(),
              retries :: non_neg_integer(),
              reason :: term()
            ) :: term()

  @typedoc """
  See `Edgehog.Provisioner.Behaviour.resource()`.
  """
  @type resource() :: Provisioner.Behaviour.resource()

  @type error() :: term()
end
