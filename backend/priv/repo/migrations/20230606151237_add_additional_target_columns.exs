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

defmodule Edgehog.Repo.Migrations.AddAdditionalTargetColumns do
  use Ecto.Migration

  def change do
    create unique_index(:ota_operations, [:id, :tenant_id])

    alter table(:update_campaign_targets) do
      add :retry_count, :integer, default: 0
      add :latest_attempt, :utc_datetime_usec
      add :completion_timestamp, :utc_datetime_usec

      add :ota_operation_id,
          references(:ota_operations,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            on_delete: :nothing
          )
    end
  end
end
