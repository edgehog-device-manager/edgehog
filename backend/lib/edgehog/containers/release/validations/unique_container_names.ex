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

defmodule Edgehog.Containers.Release.Validations.UniqueContainerNames do
  @moduledoc false

  use Ash.Resource.Validation

  alias Edgehog.Containers.Release.Dependencies

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant}) do
    containers = Ash.Changeset.get_argument(changeset, :containers) || []

    with {:ok, resolved} <- Dependencies.resolve_containers(containers, tenant) do
      case duplicated_names(resolved) do
        [] ->
          :ok

        duplicates ->
          {:error,
           field: :containers,
           message: "duplicate container names: #{Enum.join(duplicates, ", ")}"}
      end
    end
  end

  defp duplicated_names(resolved_containers) do
    resolved_containers
    |> Enum.frequencies_by(& &1.name)
    |> Map.filter(fn {_name, count} -> count > 1 end)
    |> Map.keys()
    |> Enum.sort()
  end
end
