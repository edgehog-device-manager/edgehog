#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailableDeployments do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Containers.Deployment

  require Logger

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, %{tenant: tenant}) do
    case String.split(event.path, "/") do
      ["", deployment_id, "status"] ->
        state = event.value

        with {:ok, deployment} <- Containers.fetch_deployment(deployment_id, tenant: tenant),
             do: change_state(state, deployment, tenant)

      _ ->
        {:error, :unsupported_event_path}
    end
  end

  defp change_state("Started", %Deployment{} = deployment, tenant) do
    Containers.mark_deployment_as_started(deployment, tenant: tenant)
    Containers.deployment_update_resources_state(deployment, tenant: tenant)
  end

  defp change_state("Stopped", %Deployment{} = deployment, tenant) do
    Containers.mark_deployment_as_stopped(deployment, tenant: tenant)
    Containers.deployment_update_resources_state(deployment, tenant: tenant)
  end

  defp change_state(nil, %Deployment{} = deployment, tenant) do
    deployment
    |> Ash.Changeset.for_destroy(:destroy_and_gc, %{}, tenant: tenant)
    |> Ash.destroy()

    {:ok, deployment}
  end

  defp change_state(state, %Deployment{} = deployment, tenant) do
    Logger.error(
      "Unsupported state #{inspect(state)} when handling an available_deployments event for deployment #{deployment.id}",
      tenant: tenant.slug
    )

    {:error, :unsupported_event_value}
  end
end
