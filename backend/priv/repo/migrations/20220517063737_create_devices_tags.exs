#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.CreateDevicesTags do
  use Ecto.Migration

  def change do
    create table(:devices_tags, primary_key: false) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :tag_id,
          references(:tags, with: [tenant_id: :tenant_id], match: :full, on_delete: :restrict),
          null: false,
          primary_key: true

      add :device_id,
          references(:devices, with: [tenant_id: :tenant_id], match: :full, on_delete: :delete_all),
          null: false,
          primary_key: true
    end

    create index(:devices_tags, [:tag_id, :tenant_id])
    create index(:devices_tags, [:device_id, :tenant_id])
  end
end
