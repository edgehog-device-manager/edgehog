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

defmodule Edgehog.Devices.Device.ManualActions.SendCreateDeployment do
  @moduledoc false

  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.CreateDeploymentRequest.RequestData

  @send_create_deployment_request_behaviour Application.compile_env(
                                              :edgehog,
                                              :astarte_create_deployment_request_module,
                                              Edgehog.Astarte.Device.CreateDeploymentRequest
                                            )

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    with {:ok, deployment} <- Ash.Changeset.fetch_argument(changeset, :deployment),
         {:ok, deployment} <- Ash.load(deployment, release: [:containers]) do
      release = deployment.release
      containers = release.containers
      containers_ids = Enum.map(containers, & &1.id)

      data = %RequestData{
        id: release.id,
        containers: containers_ids
      }

      with {:ok, device} <- Ash.load(device, :appengine_client) do
        @send_create_deployment_request_behaviour.send_create_deployment_request(
          device.appengine_client,
          device.device_id,
          data
        )
      end
    end
  end
end
