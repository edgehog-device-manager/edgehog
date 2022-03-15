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

defmodule Edgehog.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string, null: false
      add :device_id, :string, null: false

      add :realm_id,
          references(:realms, with: [tenant_id: :tenant_id], match: :full, on_delete: :nothing),
          null: false

      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create index(:devices, [:realm_id])
    create index(:devices, [:tenant_id])
  end
end
