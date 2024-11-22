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

defmodule Edgehog.Containers.Container.Calculations.ContainerReady do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Edgehog.Containers

  @impl Calculation
  def load(_query, _opts, _context) do
    [container: [:image, :networks, :volumes], device: []]
  end

  @impl Calculation
  def calculate(records, _opts, context) do
    %{tenant: tenant} = context
    Enum.map(records, &compute_ready(&1, tenant))
  end

  defp compute_ready(deployment, tenant) do
    container = deployment.container
    device = deployment.device

    image =
      Containers.fetch_image_deployment!(container.image.id, device.id,
        tenant: tenant,
        load: [:ready?]
      )

    networks =
      Enum.map(
        container.networks,
        &Containers.fetch_network_deployment!(&1.id, device.id, tenant: tenant, load: [:ready?])
      )

    volumes =
      Enum.map(
        container.volumes,
        &Containers.fetch_volume_deployment!(&1.id, device.id, tenant: tenant, load: [:ready?])
      )

    resources = [image | networks ++ volumes]

    Enum.reduce_while(resources, true, fn resource, _ ->
      if resource.ready? do
        {:cont, true}
      else
        {:halt, false}
      end
    end)
  end
end
