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

defmodule Edgehog.Devices.Device.ManualActions.UpdateApplication do
  @moduledoc false
  use Ash.Resource.ManualUpdate

  alias Edgehog.Astarte.Device.DeploymentUpdate.RequestData
  alias Edgehog.Containers.Deployment

  @deployment_update Application.compile_env(
                       :edgehog,
                       :astarte_deployment_update_module,
                       Edgehog.Astarte.Device.DeploymentUpdate
                     )

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    with {:ok, from} <- Ash.Changeset.fetch_argument(changeset, :from),
         {:ok, to} <- Ash.Changeset.fetch_argument(changeset, :to),
         {:ok, from} <- fetch_deployment(device, from),
         {:ok, to} <- fetch_deployment(device, to),
         {:ok, device} <- Ash.load(device, :appengine_client),
         data = %RequestData{from: from.id, to: to.id},
         :ok <- @deployment_update.update(device.appengine_client, device.device_id, data) do
      {:ok, device}
    end
  end

  defp fetch_deployment(device, release) do
    Ash.get(Deployment, %{device_id: device.id, release_id: release.id}, tenant: device.tenant_id)
  end
end
