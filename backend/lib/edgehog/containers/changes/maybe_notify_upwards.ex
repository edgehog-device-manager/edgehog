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

defmodule Edgehog.Containers.Changes.MaybeNotifyUpwards do
  @moduledoc """
  If the deployment of a containre-related resource is ready, notifies the
  appropriate container deployments about it.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, resource_deployment ->
      resource_deployment = Ash.load!(resource_deployment, [:is_ready, :container_deployments])

      if resource_deployment.is_ready,
        do: maybe_notify_upwards(resource_deployment),
        else: {:ok, resource_deployment}
    end)
  end

  defp maybe_notify_upwards(resource_deployment) do
    resource_deployment
    |> Map.get(:container_deployments, [])
    |> Enum.reduce_while({:ok, resource_deployment}, fn container_deployment, {:ok, resource_deployment} ->
      case notify_upwards(container_deployment) do
        {:ok, _} -> {:cont, {:ok, resource_deployment}}
        error -> {:halt, error}
      end
    end)
  end

  defp notify_upwards(container_deployment) do
    container_deployment
    |> Ash.Changeset.for_update(:maybe_notify_upwards, %{})
    |> Ash.update()
  end
end
