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

defmodule Edgehog.Containers.Container.Changes.MaybeNotifyUpwards do
  @moduledoc """
  If the container deployment is ready, notify the associated deployments.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, container_deployment ->
      container_deployment = Ash.load!(container_deployment, [:is_ready, :deployments])

      if container_deployment.is_ready,
        do: maybe_notify_upwards(container_deployment),
        else: {:ok, container_deployment}
    end)
  end

  defp maybe_notify_upwards(container_deployment) do
    container_deployment
    |> Map.get(:deployments, [])
    |> Enum.reduce_while({:ok, container_deployment}, fn deployment, {:ok, container_deployment} ->
      case notify_upwards(deployment) do
        {:ok, _} -> {:cont, {:ok, container_deployment}}
        error -> {:halt, error}
      end
    end)
  end

  defp notify_upwards(deployment) do
    deployment
    |> Ash.Changeset.for_update(:maybe_run_ready_actions, %{})
    |> Ash.update()
  end
end
