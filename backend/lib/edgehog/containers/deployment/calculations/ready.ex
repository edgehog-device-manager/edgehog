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

defmodule Edgehog.Containers.Deployment.Calculations.Ready do
  @moduledoc """
  Computes the readiness of a deployment.
  A deployment is ready when:
   - Its state is either `:started` or `:stopped`
   - All underlying container deployments are ready
  """

  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @ready_states [:started, :stopped]

  @impl Calculation
  def load(_query, _opts, _context), do: [state: [], container_deployments: :is_ready]

  @impl Calculation
  def calculate(deployments, _opts, _context) do
    Enum.map(deployments, &ready?/1)
  end

  defp ready?(deployment) do
    self = deployment.state in @ready_states

    others =
      deployment.container_deployments
      |> Enum.map(& &1.is_ready)
      |> Enum.all?()

    # A great lesson on consent here
    self and others
  end
end
