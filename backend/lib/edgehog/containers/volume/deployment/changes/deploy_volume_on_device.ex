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

defmodule Edgehog.Containers.Volume.Deployment.Changes.DeployVolumeOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Devices

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    volume_deployment = changeset.data
    deployment = Ash.Changeset.get_argument(changeset, :deployment)

    with {:ok, volume_deployment} <-
           Ash.load(volume_deployment, [:volume, :device, :state], tenant: tenant) do
      volume = volume_deployment.volume
      device = volume_deployment.device

      with {:ok, _device} <- Devices.send_create_volume_request(device, volume, deployment) do
        maybe_update_state(changeset, volume_deployment.state)
      end
    end
  end

  defp maybe_update_state(changeset, :created), do: Ash.Changeset.change_attribute(changeset, :state, :sent)

  defp maybe_update_state(changeset, _), do: changeset
end
