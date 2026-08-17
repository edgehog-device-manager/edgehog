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

defmodule Edgehog.Containers.Deployment.Provisioner do
  @moduledoc """
  A deployment provisioner.

  Each and every time a deployment should be provisioned, it can be done through
  this Service. The provisioner sends the appropriate messages to the device and
  emits an event on `deployments:provisioning:<id>` topic whenever
  deployment is present in the device.

  The provisioning flow can be described as follows:

  - `start_link/1` is called, initializing the process and subscribing to the
    events emitted on `deployments:<id>` (id of the deployment)
  - if the deployment is already ready, the provisioner terminates normally right
    away, broadcasting readiness
  - otherwise the appropriate messages are sent to the device through the
    `Core` module (see `Core.send/1` docs for more info)

  Nice flow (everything goes ok)
  - Astarte triggers update the deployment state, marking it as present or
    not present and emitting an event on the correct topic
  - The server reacts to the event, handles the message and emits an event on
    `deployments:provisioning:<id>` when the resource is ready
  - listening processes can react to this information

  Timeouts (something goes wrong)
  - `Core.send/1` failed, maybe the device is offline, or there was some
    problem with astarte
  - an exponential backoff timeout is started
  - A :timeout hits the server, it retries to send the deployment information to the
    device

  For more information, check the `Edgehog.Containers.Provisioner` docs.
  """
  use Edgehog.Containers.Provisioner,
    resource: Edgehog.Containers.Deployment,
    core: Edgehog.Containers.Deployment.Provisioner.Core

  @sup Edgehog.Containers.Deployment.Provisioner.Supervisor
end
