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

defmodule Edgehog.Astarte.Device.DeploymentCommand do
  @moduledoc false

  @behaviour Edgehog.Astarte.Device.DeploymentCommand.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.DeploymentCommand.RequestData
  alias Edgehog.Error

  @interface "io.edgehog.devicemanager.apps.DeploymentCommand"

  @impl Edgehog.Astarte.Device.DeploymentCommand.Behaviour
  def send_deployment_command(client, device_id, data) do
    %RequestData{command: command, deployment_id: deployment_id} = data

    path = "/#{deployment_id}/command"

    client
    |> AppEngine.Devices.send_datastream(device_id, @interface, path, command)
    |> Error.maybe_match_error(device_id, @interface)
  end
end
