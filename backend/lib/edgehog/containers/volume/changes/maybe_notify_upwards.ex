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

defmodule Edgehog.Containers.Volume.Changes.MaybeNotifyUpwards do
  @moduledoc """
  If the deployment is in a ready state, notify all container_deployments that it is ready.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.load(:is_ready)
    |> Ash.Changeset.load(:container_deployments)
    |> Ash.Changeset.after_action(fn _changeset, volume_deployment ->
      if volume_deployment.is_ready,
        do:
          volume_deployment
          |> Map.get(:container_deployments, [])
          |> Enum.reduce_while({:ok, volume_deployment}, fn container_deployment, {:ok, volume_deployment} ->
            case maybe_notify_upwards(container_deployment) do
              {:ok, _} -> {:cont, {:ok, volume_deployment}}
              error -> {:halt, error}
            end
          end),
        else: {:ok, volume_deployment}
    end)
  end

  defp maybe_notify_upwards(container_deployment) do
    container_deployment
    |> Ash.Changeset.for_update(:maybe_notify_upwards, %{})
    |> Ash.update()
  end
end
