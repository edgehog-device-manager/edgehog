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

defmodule Edgehog.Devices.Device.ManualActions.SendApplicationCommand do
  @moduledoc false
  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.DeploymentCommand.RequestData
  alias Edgehog.Containers.Release.Deployment

  @deployment_command Application.compile_env(
                        :edgehog,
                        :astarte_deployment_command_module,
                        Edgehog.Astarte.Device.DeploymentCommand
                      )

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    command = changeset.arguments.command
    release = changeset.arguments.release
    device = changeset.data

    with {:ok, command} <- deployment_command_from_enum(command),
         {:ok, deployment} <- fetch_deployment(device, release),
         {:ok, device} <- Ash.load(device, :appengine_client),
         data = %RequestData{deployment_id: deployment.id, command: command},
         :ok <-
           @deployment_command.send_deployment_command(
             device.appengine_client,
             device.device_id,
             data
           ) do
      {:ok, device}
    end
  end

  defp deployment_command_from_enum(command) do
    case command do
      :start -> {:ok, "Start"}
      :stop -> {:ok, "Stop"}
      :delete -> {:ok, "Delete"}
      _ -> {:error, "Unknown deployment command"}
    end
  end

  defp fetch_deployment(device, release) do
    Ash.get(Deployment, %{device_id: device.id, release_id: release.id}, tenant: device.tenant_id)
  end
end
