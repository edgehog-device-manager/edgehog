#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Network.Changes.DeployNetworkOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Devices

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    network_deployment = changeset.data
    deployment = Ash.Changeset.get_argument(changeset, :deployment)

    with {:ok, network_deployment} <-
           Ash.load(network_deployment, [:network, :device], tenant: tenant) do
      network = network_deployment.network
      device = network_deployment.device

      with {:ok, _device} <-
             Devices.send_create_network_request(device, network, deployment, tenant: tenant) do
        Ash.Changeset.change_attribute(changeset, :state, :sent)
      end
    end
  end
end
