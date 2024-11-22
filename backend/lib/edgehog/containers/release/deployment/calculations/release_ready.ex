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

defmodule Edgehog.Containers.Release.Deployment.Calculations.ReleaseReady do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Edgehog.Containers

  # @impl Calculation
  # def load(_query, opts, _context) do
  #   [release: [containers: [:ready?]]]
  # end

  @impl Calculation
  def calculate(records, _opts, context) do
    %{tenant: tenant} = context
    Enum.map(records, &ready?(&1, tenant))
  end

  defp ready?(deployment, tenant) do
    with {:ok, deployment} <-
           Ash.load(deployment, [release: [:containers], device: []], tenant: tenant) do
      containers = deployment.release.containers
      device = deployment.device

      containers
      |> Enum.map(&load_container_deployment(&1, device, tenant))
      |> Enum.all?(fn deployment -> deployment.ready? end)
    end
  end

  defp load_container_deployment(container, device, tenant) do
    Containers.fetch_container_deployment!(container.id, device.id,
      tenant: tenant,
      load: [:ready?]
    )
  end
end
