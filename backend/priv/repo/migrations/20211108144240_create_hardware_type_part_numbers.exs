#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.CreateHardwareTypePartNumbers do
  use Ecto.Migration

  def change do
    create table(:hardware_type_part_numbers) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :part_number, :string, null: false

      add :hardware_type_id,
          references(:hardware_types, with: [tenant_id: :tenant_id], on_delete: :delete_all)

      timestamps()
    end

    create index(:hardware_type_part_numbers, [:hardware_type_id])
    create index(:hardware_type_part_numbers, [:tenant_id])
    create unique_index(:hardware_type_part_numbers, [:part_number, :tenant_id])
  end
end
