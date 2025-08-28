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

defmodule Edgehog.Containers.Container.Calculations.Ready do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Edgehog.Containers

  @impl Calculation
  def load(_query, _opts, _context) do
    [container: [:image, :networks, :volumes], device: []]
  end

  @impl Calculation
  def calculate(records, _opts, %{tenant: tenant}) do
    Enum.map(records, &compute_ready(&1, tenant))
  end

  defp compute_ready(deployment, tenant) do
    missing_image = missing_image(deployment, tenant)
    missing_networks = missing_networks(deployment, tenant)
    missing_volumes = missing_volumes(deployment, tenant)

    self =
      if deployment.state in [:created, :error, :sent],
        do: [deployment],
        else: []

    missing = missing_image ++ missing_networks ++ missing_volumes ++ self

    case missing do
      [] -> :ready
      missing_resources -> {:not_ready, missing_resources}
    end
  end

  defp missing_image(deployment, tenant) do
    container = deployment.container

    ready? =
      container.image.id
      |> Containers.fetch_image_deployment!(deployment.device.id, tenant: tenant)
      |> Ash.load!([:ready?], tenant: tenant)
      |> Map.get(:ready?)

    if ready? do
      []
    else
      [container.image]
    end
  end

  defp missing_networks(deployment, tenant) do
    Enum.flat_map(deployment.container.networks, fn network ->
      network_ready? =
        network.id
        |> Containers.fetch_network_deployment!(deployment.device.id, tenant: tenant)
        |> Ash.load!([:ready?], tenant: tenant)
        |> Map.get(:ready?)

      if network_ready?, do: [], else: [network]
    end)
  end

  defp missing_volumes(deployment, tenant) do
    Enum.flat_map(deployment.container.volumes, fn volume ->
      volume_ready? =
        volume.id
        |> Containers.fetch_volume_deployment!(deployment.device.id, tenant: tenant)
        |> Ash.load!([:ready?], tenant: tenant)
        |> Map.get(:ready?)

      if volume_ready?, do: [], else: [volume]
    end)
  end
end
