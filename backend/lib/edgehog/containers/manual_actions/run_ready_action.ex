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

defmodule Edgehog.Containers.ManualActions.RunReadyAction do
  @moduledoc false

  use Ash.Resource.ManualUpdate

  alias Edgehog.Devices

  require Ash.Query

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    ready_action = changeset.data
    action_type = ready_action.action_type

    :upgrade_deployment = action_type
    extra_loads = [upgrade_deployment: [:upgrade_target]]

    # We always load the device
    loads = extra_loads ++ [deployment: [:device]]

    with {:ok, ready_action} <- Ash.load(ready_action, loads),
         :ok <- run_ready_action(ready_action, action_type) do
      {:ok, ready_action}
    end
  end

  defp run_ready_action(action, :upgrade_deployment) do
    with {:ok, _device} <-
           Devices.update_application(
             action.deployment.device,
             action.upgrade_deployment.upgrade_target,
             action.deployment
           ) do
      :ok
    end
  end
end
