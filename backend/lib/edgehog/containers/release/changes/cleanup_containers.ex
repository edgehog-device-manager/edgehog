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

defmodule Edgehog.Containers.Release.Changes.CleanupContainers do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    release = changeset.data
    %{tenant: tenant} = context

    case Ash.load(release, :containers, tenant: tenant) do
      {:ok, release} ->
        containers = release.containers

        Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
          maybe_cleanup(result, containers, tenant)
        end)

      _ ->
        changeset
    end
  end

  defp maybe_cleanup({:ok, _} = result, containers, tenant) do
    for container <- containers do
      Containers.destroy_container_if_dangling(container, tenant: tenant)
    end

    result
  end

  defp maybe_cleanup(result, _containers, _tenant), do: result
end
