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

defmodule Edgehog.Repo.Migrations.VolumeDeployment do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:application_volume_deployments, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :last_message, :text
      add :state, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "application_volume_deployments_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :volume_id,
          references(:volumes,
            column: :id,
            name: "application_volume_deployments_volume_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :device_id,
          references(:devices,
            column: :id,
            name: "application_volume_deployments_device_id_fkey",
            type: :bigint,
            prefix: "public"
          )
    end

    create index(:application_volume_deployments, [:tenant_id])

    create index(:application_volume_deployments, [:id, :tenant_id], unique: true)

    create unique_index(:application_volume_deployments, [:tenant_id, :volume_id, :device_id],
             name: "application_volume_deployments_volume_instance_index"
           )
  end

  def down do
    drop_if_exists unique_index(
                     :application_volume_deployments,
                     [:tenant_id, :volume_id, :device_id],
                     name: "application_volume_deployments_volume_instance_index"
                   )

    drop constraint(
           :application_volume_deployments,
           "application_volume_deployments_tenant_id_fkey"
         )

    drop constraint(
           :application_volume_deployments,
           "application_volume_deployments_volume_id_fkey"
         )

    drop constraint(
           :application_volume_deployments,
           "application_volume_deployments_device_id_fkey"
         )

    drop_if_exists index(:application_volume_deployments, [:id, :tenant_id])

    drop_if_exists index(:application_volume_deployments, [:tenant_id])

    drop table(:application_volume_deployments)
  end
end
