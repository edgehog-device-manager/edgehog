#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.RenameMaxErrorsPercentageToMaxFailurePercentage do
  use Ecto.Migration

  alias Edgehog.Repo
  import Ecto.Query

  @old_name "max_errors_percentage"
  @new_name "max_failure_percentage"

  def up do
    rename_rollout_mechanism_field(@old_name, @new_name)
  end

  def down do
    rename_rollout_mechanism_field(@new_name, @old_name)
  end

  defp rename_rollout_mechanism_field(old_name, new_name) do
    stream =
      from(uc in "update_campaigns",
        select: {uc.id, uc.rollout_mechanism}
      )
      |> Repo.stream(skip_tenant_id: true)

    Repo.transaction(fn ->
      stream
      |> Enum.each(fn {id, %{^old_name => value} = rollout} ->
        updated_rollout =
          rollout
          |> Map.delete(old_name)
          |> Map.put(new_name, value)

        from(uc in "update_campaigns",
          where: uc.id == ^id,
          select: uc.id
        )
        |> Repo.update_all([set: [rollout_mechanism: updated_rollout]], skip_tenant_id: true)
      end)
    end)

    :ok
  end
end
