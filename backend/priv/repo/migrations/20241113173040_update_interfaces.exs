#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.UpdateInterfaces do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:networks) do
      remove :check_duplicate
      add :options, {:array, :text}, null: false, default: []
    end

    alter table(:containers) do
      add :network_mode, :text, null: false, default: "bridge"
    end

    alter table(:application_deployments) do
      modify :device_id, :integer
    end
  end

  def down do
    alter table(:application_deployments) do
      modify :device_id, :bigint
    end

    alter table(:containers) do
      remove :network_mode
    end

    alter table(:networks) do
      remove :options
      add :check_duplicate, :boolean, null: false, default: false
    end
  end
end