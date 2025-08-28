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
  Computes whether a deployment is ready.

  A deployment is considered ready if all underlying container deployments are ready.
  """
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Edgehog.Containers

  @impl Calculation
  def load(_query, _opts, _context) do
    [release: [:containers], device: []]
  end

  @impl Calculation
  def calculate(records, _opts, %{tenant: tenant}) do
    Enum.map(records, &compute_ready(&1, tenant))
  end

  defp compute_ready(deployment, tenant) do
    missing =
      deployment.release.containers
      |> Enum.map(fn container ->
        # TODO: this will fail.
        # Here: this might crash
        Containers.fetch_container_deployment!(container.id, deployment.device.id,
          tenant: tenant,
          load: :ready?
        )
      end)
      |> Enum.reject(&(&1.ready? == :ready))

    self =
      if deployment.state in [:pending, :error, :sent],
        do: [{deployment, deployment.state}],
        else: []

    case missing ++ self do
      [] -> :ready
      missing_deployments -> {:not_ready, missing_deployments}
    end
  end
end
