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

defmodule Edgehog.Repo.Migrations.CreateUpdateCampaignTargets do
  use Ecto.Migration

  def change do
    create table(:update_campaign_targets) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :status, :string, null: false

      add :update_campaign_id,
          references(:update_campaigns,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all
          ),
          null: false

      add :device_id,
          references(:devices,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :nothing
          ),
          null: false

      timestamps()
    end

    create index(:update_campaign_targets, [:tenant_id])
    create index(:update_campaign_targets, [:device_id])
    create index(:update_campaign_targets, [:update_campaign_id])
    create unique_index(:update_campaign_targets, [:update_campaign_id, :device_id, :tenant_id])
    create unique_index(:update_campaign_targets, [:id, :tenant_id])
  end
end
