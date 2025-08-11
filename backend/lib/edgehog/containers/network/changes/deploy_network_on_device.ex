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

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    device = Ash.Changeset.get_argument(changeset, :device)
    network = Ash.Changeset.get_argument(changeset, :network)
    deployment = Ash.Changeset.get_argument(changeset, :deployment)

    Ash.Changeset.after_action(changeset, fn _changeset, network_deployment ->
      with {:ok, _device} <- Devices.send_create_network_request(device, network, deployment) do
        Containers.mark_network_deployment_as_sent(network_deployment)
      end
    end)
  end
end
