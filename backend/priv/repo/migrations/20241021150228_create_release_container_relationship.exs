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

defmodule Edgehog.Repo.Migrations.CreateReleaseContainerRelationship do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:application_release_containers, primary_key: false) do
      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "application_release_containers_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          primary_key: true,
          null: false

      add :release_id,
          references(:application_releases,
            column: :id,
            name: "application_release_containers_release_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          primary_key: true,
          null: false

      add :container_id,
          references(:containers,
            column: :id,
            name: "application_release_containers_container_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          primary_key: true,
          null: false
    end

    create index(:application_release_containers, [:tenant_id])
  end

  def down do
    drop constraint(
           :application_release_containers,
           "application_release_containers_tenant_id_fkey"
         )

    drop constraint(
           :application_release_containers,
           "application_release_containers_release_id_fkey"
         )

    drop constraint(
           :application_release_containers,
           "application_release_containers_container_id_fkey"
         )

    drop_if_exists index(:application_release_containers, [:tenant_id])

    drop table(:application_release_containers)
  end
end
