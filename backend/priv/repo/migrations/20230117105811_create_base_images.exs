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

defmodule Edgehog.Repo.Migrations.CreateBaseImages do
  use Ecto.Migration

  def change do
    create unique_index(:base_image_collections, [:id, :tenant_id])

    create table(:base_images) do
      add :tenant_id, references(:tenants, column: :tenant_id, on_delete: :delete_all),
        null: false

      add :version, :string, null: false
      add :release_display_name, :map
      add :description, :map
      add :starting_version_requirement, :string

      add :base_image_collection_id,
          references(:base_image_collections,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :nothing
          ),
          null: false

      timestamps()
    end

    create unique_index(:base_images, [:version, :base_image_collection_id, :tenant_id])
    create index(:base_images, [:base_image_collection_id, :tenant_id])
    create index(:base_images, [:tenant_id])
  end
end
