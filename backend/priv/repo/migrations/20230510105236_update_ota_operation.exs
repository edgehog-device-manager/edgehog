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

defmodule Edgehog.Repo.Migrations.UpdateOtaOperation do
  use Ecto.Migration

  alias Edgehog.Repo
  import Ecto.Query

  @old_status_to_new_status %{
    "InProgress" => "Acknowledged",
    "Error" => "Failure",
    "Done" => "Success"
  }

  @new_status_to_old_status for {old, new} <- @old_status_to_new_status, into: %{}, do: {new, old}

  @old_code_to_new_code %{
    "OTAErrorNetwork" => "NetworkError",
    "OTAErrorNvs" => nil,
    "OTAAlreadyInProgress" => "UpdateAlreadyInProgress",
    "OTAFailed" => nil,
    "OTAErrorDeploy" => "IOError",
    "OTAErrorBootWrongPartition" => "SystemRollback"
  }

  # We skip error codes that map to nil since they don't map to a new status code
  # This loses some (non-essential) information if migrating and then rolling back
  @new_code_to_old_code for {old, new} <- @old_code_to_new_code,
                            new != nil,
                            into: %{},
                            do: {new, old}

  def up do
    alter table("ota_operations") do
      add :status_progress, :integer, null: false, default: 0
      add :message, :string
    end

    Enum.each(@old_status_to_new_status, fn {old, new} ->
      replace(:status, old, new)
    end)

    Enum.each(@old_code_to_new_code, fn {old, new} ->
      replace(:status_code, old, new)
    end)
  end

  def down do
    Enum.each(@new_code_to_old_code, fn {new, old} ->
      replace(:status_code, new, old)
    end)

    Enum.each(@new_status_to_old_status, fn {new, old} ->
      replace(:status, new, old)
    end)

    alter table("ota_operations") do
      remove :status_progress
      remove :message, :string
    end
  end

  defp replace(field, current, replacement) when is_atom(field) do
    update_args = [{field, replacement}]

    query =
      from(o in "ota_operations",
        where: field(o, ^field) == ^current,
        update: [set: ^update_args]
      )

    Repo.update_all(query, [], skip_tenant_id: true)
  end
end
