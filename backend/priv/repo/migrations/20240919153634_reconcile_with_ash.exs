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

defmodule Edgehog.Repo.Migrations.ReconcileWithAsh do
  @moduledoc false
  use Ecto.Migration

  def change do
    # These changes are needed to manually reconcile our current database state
    # with what Ash expects when generating its migration, se we can start using
    # the migration generator
    #
    # Recap of the changes that are happening here:
    # - Change string columns to text (character varying(255) -> text)
    # - Add defaults at the database level to inserted_at and updated_at
    # - Add additional defaults at the database level if Ash pushes them there (Ecto just
    #   adds them at the struct creation level)

    alter table(:base_image_collections) do
      modify :name, :text, from: :string, null: false
      modify :handle, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:base_images) do
      modify :version, :text, from: :string, null: false
      modify :url, :text, from: :string, null: false
      modify :starting_version_requirement, :text, from: :string

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:clusters) do
      modify :name, :text, from: :string
      modify :base_api_url, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:device_groups) do
      modify :name, :text, from: :string, null: false
      modify :handle, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:devices) do
      modify :name, :text, from: :string, null: false
      modify :device_id, :text, from: :string, null: false
      modify :serial_number, :text, from: :string
      modify :part_number, :text, from: :string

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:hardware_type_part_numbers) do
      modify :part_number, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:hardware_type_part_numbers) do
      modify :part_number, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:hardware_types) do
      modify :name, :text, from: :string, null: false
      modify :handle, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:ota_operations) do
      modify :id, :uuid, null: false, default: fragment("gen_random_uuid()")
      modify :base_image_url, :text, from: :string, null: false
      modify :status, :text, from: :string, null: false, default: "pending"
      modify :status_code, :text, from: :string
      modify :message, :text, from: :string
      modify :is_manual, :boolean, default: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:realms) do
      modify :name, :text, from: :string, null: false
      modify :private_key, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:system_model_part_numbers) do
      modify :part_number, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:system_models) do
      modify :name, :text, from: :string, null: false
      modify :handle, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:tags) do
      modify :name, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:tenants) do
      modify :name, :text, from: :string, null: false
      modify :slug, :text, from: :string, null: false
      modify :default_locale, :text, from: :string, null: false, default: "en-US"

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:update_campaign_targets) do
      modify :retry_count, :bigint, from: :integer, null: false
      modify :status, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:update_campaigns) do
      modify :name, :text, from: :string, null: false
      modify :status, :text, from: :string, null: false
      modify :outcome, :text, from: :string

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    alter table(:update_channels) do
      modify :name, :text, from: :string, null: false
      modify :handle, :text, from: :string, null: false

      modify :inserted_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      modify :updated_at, :utc_datetime_usec,
        from: :naive_datetime,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    # Ash puts :tenant_id first in indexes, while we had it as last merely to have a better Ecto
    # error message. We need to swap all things around.
    # When we drop the index we don't pass and explicit name because it was generated with the
    # Ecto default name. When we create it we pass it explicitly to match what Ash migrations
    # expect.
    # So in this block we mainly swap columns around to adhere to what Ash generates

    drop_if_exists unique_index(:base_image_collections, [:handle, :tenant_id])

    create unique_index(:base_image_collections, [:tenant_id, :handle],
             name: "base_image_collections_handle_index"
           )

    drop_if_exists unique_index(:base_image_collections, [:name, :tenant_id])

    create unique_index(:base_image_collections, [:tenant_id, :name],
             name: "base_image_collections_name_index"
           )

    drop_if_exists unique_index(:base_image_collections, [:system_model_id, :tenant_id])

    create unique_index(:base_image_collections, [:tenant_id, :system_model_id],
             name: "base_image_collections_system_model_id_index"
           )

    drop_if_exists index(:base_images, [:base_image_collection_id, :tenant_id])
    create index(:base_images, [:tenant_id, :base_image_collection_id])

    drop_if_exists unique_index(:base_images, [:version, :base_image_collection_id, :tenant_id])

    create unique_index(:base_images, [:tenant_id, :version, :base_image_collection_id],
             name: "base_images_unique_base_image_collection_version_index"
           )

    rename(unique_index(:clusters, [:base_api_url]), to: "clusters_url_index")

    drop_if_exists unique_index(:device_groups, [:handle, :tenant_id])
    create unique_index(:device_groups, [:tenant_id, :handle], name: "device_groups_handle_index")

    drop_if_exists unique_index(:device_groups, [:name, :tenant_id])
    create unique_index(:device_groups, [:tenant_id, :name], name: "device_groups_name_index")

    drop_if_exists unique_index(:devices, [:device_id, :realm_id, :tenant_id])

    create unique_index(:devices, [:tenant_id, :device_id, :realm_id],
             name: "devices_unique_realm_device_id_index"
           )

    drop_if_exists index(:devices_tags, [:device_id, :tenant_id])
    create index(:devices_tags, [:tenant_id, :device_id])

    drop_if_exists index(:devices_tags, [:tag_id, :tenant_id])
    create index(:devices_tags, [:tenant_id, :tag_id])

    drop_if_exists unique_index(:hardware_type_part_numbers, [:part_number, :tenant_id])

    create unique_index(:hardware_type_part_numbers, [:tenant_id, :part_number],
             name: "hardware_type_part_numbers_part_number_index"
           )

    drop_if_exists unique_index(:hardware_types, [:handle, :tenant_id])

    create unique_index(:hardware_types, [:tenant_id, :handle],
             name: "hardware_types_handle_index"
           )

    drop_if_exists unique_index(:hardware_types, [:name, :tenant_id])
    create unique_index(:hardware_types, [:tenant_id, :name], name: "hardware_types_name_index")

    drop_if_exists unique_index(:realms, [:name, :tenant_id])
    create unique_index(:realms, [:tenant_id, :name], name: "realms_name_index")

    rename(unique_index(:realms, [:name, :cluster_id]),
      to: "realms_unique_name_for_cluster_index"
    )

    drop_if_exists unique_index(:system_model_part_numbers, [:part_number, :tenant_id])

    create unique_index(:system_model_part_numbers, [:tenant_id, :part_number],
             name: "system_model_part_numbers_part_number_index"
           )

    drop_if_exists unique_index(:system_models, [:handle, :tenant_id])
    create unique_index(:system_models, [:tenant_id, :handle], name: "system_models_handle_index")

    drop_if_exists unique_index(:system_models, [:name, :tenant_id])
    create unique_index(:system_models, [:tenant_id, :name], name: "system_models_name_index")

    drop_if_exists unique_index(:tags, [:name, :tenant_id])
    create unique_index(:tags, [:tenant_id, :name], name: "tags_name_index")

    drop_if_exists unique_index(:update_campaign_targets, [
                     :update_campaign_id,
                     :device_id,
                     :tenant_id
                   ])

    create unique_index(:update_campaign_targets, [:tenant_id, :update_campaign_id, :device_id],
             name: "update_campaign_targets_unique_device_for_campaign_index"
           )

    drop_if_exists index(:update_campaigns, [:base_image_id, :tenant_id])
    create index(:update_campaigns, [:tenant_id, :base_image_id])

    drop_if_exists index(:update_campaigns, [:update_channel_id, :tenant_id])
    create index(:update_campaigns, [:tenant_id, :update_channel_id])

    drop_if_exists unique_index(:update_channels, [:handle, :tenant_id])

    create unique_index(:update_channels, [:tenant_id, :handle],
             name: "update_channels_handle_index"
           )

    drop_if_exists unique_index(:update_channels, [:name, :tenant_id])
    create unique_index(:update_channels, [:tenant_id, :name], name: "update_channels_name_index")

    # Our MultitenantResource now creates a unique index on `[:id, :tenant_id]` for _all_ resources
    # This allows using composite foreign keys to enforce associated resources are on in the same
    # tenant at the database level.
    # We add just _some_ of those indexes, so we manually create the missing ones
    create unique_index(:device_groups, [:id, :tenant_id])
    create unique_index(:hardware_type_part_numbers, [:id, :tenant_id])
    create unique_index(:system_model_part_numbers, [:id, :tenant_id])

    # These tables were missing the index on :tenant_id
    create index(:base_image_collections, [:tenant_id])
    create index(:devices_tags, [:tenant_id])

    # This was an unnoticed mistake and just has to be dropped
    drop unique_index(:system_model_part_numbers, [:part_number, :id])
  end
end
