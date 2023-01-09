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

defmodule Edgehog.Repo.Migrations.EmbedSystemModelDescriptions do
  use Ecto.Migration
  import Ecto.Query
  alias Edgehog.Devices.SystemModel
  alias Edgehog.Repo

  def up do
    alter table("system_models") do
      add :description, :map
    end

    flush()

    descriptions =
      from(smd in "system_model_descriptions",
        select: {{smd.tenant_id, smd.system_model_id}, {smd.locale, smd.text}}
      )
      |> Repo.all(schema_migration: true)
      |> Enum.reduce(%{}, fn el, acc ->
        {key, {locale, text}} = el
        Map.update(acc, key, %{locale => text}, &Map.put(&1, locale, text))
      end)

    upserts =
      from(sm in "system_models",
        select: %{
          tenant_id: sm.tenant_id,
          id: sm.id,
          name: sm.name,
          handle: sm.handle,
          picture_url: sm.picture_url,
          hardware_type_id: sm.hardware_type_id
        }
      )
      |> Repo.all(schema_migration: true)
      |> Enum.map(fn system_model ->
        %{tenant_id: tenant_id, id: id} = system_model
        key = {tenant_id, id}
        locale_map = Map.get(descriptions, key)

        system_model
        |> Map.put(:description, locale_map)
        |> Map.put(:inserted_at, {:placeholder, :timestamp})
        |> Map.put(:updated_at, {:placeholder, :timestamp})
      end)

    timestamp =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    placeholders = %{timestamp: timestamp}

    Repo.insert_all(SystemModel, upserts,
      placeholders: placeholders,
      conflict_target: [:id, :tenant_id],
      on_conflict: {:replace, [:description, :updated_at]}
    )

    drop table("system_model_descriptions")
  end

  def down do
    create table(:system_model_descriptions) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :locale, :string, null: false
      add :text, :text, null: false

      add :system_model_id,
          references(:system_models,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all
          ),
          null: false

      timestamps()
    end

    create index(:system_model_descriptions, [:tenant_id])
    create index(:system_model_descriptions, [:system_model_id, :tenant_id])
    create unique_index(:system_model_descriptions, [:locale, :system_model_id, :tenant_id])

    flush()

    maps =
      from(sm in "system_models",
        select: %{id: sm.id, tenant_id: sm.tenant_id, description: sm.description}
      )
      |> Repo.all(schema_migration: true)
      |> Enum.flat_map(fn entry ->
        %{id: system_model_id, tenant_id: tenant_id, description: description} = entry

        Enum.map(description || %{}, fn {locale, text} ->
          %{
            tenant_id: tenant_id,
            system_model_id: system_model_id,
            locale: locale,
            text: text,
            inserted_at: {:placeholder, :timestamp},
            updated_at: {:placeholder, :timestamp}
          }
        end)
      end)

    timestamp =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    placeholders = %{timestamp: timestamp}

    Repo.insert_all("system_model_descriptions", maps, placeholders: placeholders)

    alter table("system_models") do
      remove :description
    end
  end
end
