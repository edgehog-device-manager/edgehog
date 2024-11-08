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

defmodule Edgehog.Astarte.Device.AvailableDeployments do
  @moduledoc false

  @behaviour Edgehog.Astarte.Device.AvailableDeployments.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailableDeployments.DeploymentStatus

  @interface "io.edgehog.devicemanager.apps.AvailableDeployments"

  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface) do
      deployments = Enum.map(data, &parse_available_deployment/1)

      {:ok, deployments}
    end
  end

  defp parse_available_deployment({deployment_id, parameters}) do
    status =
      case parameters["status"] do
        "Stopped" -> :stopped
        "Started" -> :started
      end

    %DeploymentStatus{
      id: deployment_id,
      status: status
    }
  end
end
