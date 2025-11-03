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

defmodule Edgehog.Containers.Changes.MaybeDestroyChildren do
  @moduledoc """
  Trigger children cleanup (if dangling) after transaction.
  """

  use Ash.Resource.Change

  alias Ash.Resource.Change

  @children_key :children

  @impl Change
  def init(opts) do
    if Keyword.has_key?(opts, @children_key),
      do: {:ok, opts},
      else: {:error, :missing_children}
  end

  @impl Change
  def change(changeset, opts, %{tenant: tenant}) do
    children = Keyword.fetch!(opts, @children_key)

    with {:ok, resource} <- Ash.load(changeset.data, children) do
      children =
        children
        |> Enum.map(&Map.get(resource, &1, nil))
        |> List.flatten()

      Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
        with {:ok, resource} <- result do
          maybe_destroy_resources(children, tenant)
          {:ok, resource}
        end
      end)
    end
  end

  defp maybe_destroy_resources(resources, tenant) do
    Enum.each(resources, fn resource ->
      resource
      |> Ash.Changeset.for_destroy(:destroy_if_dangling, %{})
      |> Ash.destroy(tenant: tenant)
    end)
  end
end
