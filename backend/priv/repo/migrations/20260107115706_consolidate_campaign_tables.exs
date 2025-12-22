#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.ConsolidateCampaignTables do
  @moduledoc """
  Consolidates update_campaigns/update_campaign_targets and deployment_campaigns/deployment_targets
  into unified campaigns and campaign_targets tables.

  This migration:
  1. Creates the new unified campaigns and campaign_targets tables
  2. Migrates all data from update_campaigns to campaigns (with rollout_mechanism -> campaign_mechanism)
  3. Migrates all data from deployment_campaigns to campaigns (with deployment_mechanism -> campaign_mechanism)
  4. Migrates all update_campaign_targets to campaign_targets
  5. Migrates all deployment_targets to campaign_targets
  6. Drops the legacy tables
  """

  use Ecto.Migration

  require Ash.Query

  def up do
    # Step 1: Create the new unified campaigns table
    create table(:campaigns, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :status, :text, null: false
      add :outcome, :text
      add :campaign_mechanism, :map, null: false
      add :start_timestamp, :utc_datetime_usec
      add :completion_timestamp, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "campaigns_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :channel_id,
          references(:channels,
            column: :id,
            with: [tenant_id: :tenant_id],
            match: :full,
            name: "campaigns_channel_id_fkey",
            type: :integer,
            prefix: "public",
            on_delete: :nothing
          ),
          null: false
    end

    create index(:campaigns, [:tenant_id])
    create index(:campaigns, [:id, :tenant_id], unique: true)
    create index(:campaigns, [:tenant_id, :channel_id])

    # Step 2: Create the new unified campaign_targets table
    create table(:campaign_targets, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :status, :text, null: false
      add :retry_count, :bigint, null: false, default: 0
      add :latest_attempt, :utc_datetime_usec
      add :completion_timestamp, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "campaign_targets_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :campaign_id,
          references(:campaigns,
            column: :id,
            name: "campaign_targets_campaign_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :device_id,
          references(:devices,
            column: :id,
            name: "campaign_targets_device_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :deployment_id,
          references(:application_deployments,
            column: :id,
            name: "campaign_targets_deployment_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          )

      add :ota_operation_id,
          references(:ota_operations,
            column: :id,
            name: "campaign_targets_ota_operation_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          )
    end

    create index(:campaign_targets, [:tenant_id])
    create index(:campaign_targets, [:id, :tenant_id], unique: true)

    # Step 3: Migrate data from legacy tables to unified tables

    # Migrate deployment_campaigns to campaigns
    execute """
    INSERT INTO campaigns (
      id,
      name,
      status,
      outcome,
      campaign_mechanism,
      start_timestamp,
      completion_timestamp,
      inserted_at,
      updated_at,
      tenant_id,
      channel_id
    )
    SELECT
      dc.id,
      dc.name,
      dc.status,
      dc.outcome,
      jsonb_strip_nulls(
        jsonb_build_object(
          'type',
            CASE dc.operation_type
              WHEN 'deploy'  THEN 'deployment_deploy'
              WHEN 'start'   THEN 'deployment_start'
              WHEN 'stop'    THEN 'deployment_stop'
              WHEN 'upgrade' THEN 'deployment_upgrade'
              WHEN 'delete'  THEN 'deployment_delete'
              ELSE 'deployment_deploy'
            END,
          'release_id', dc.release_id,
          'target_release_id', CASE WHEN dc.operation_type = 'upgrade' THEN dc.target_release_id END,
          'request_retries', (dc.deployment_mechanism->>'create_request_retries')::int,
          'max_failure_percentage', (dc.deployment_mechanism->>'max_failure_percentage')::float,
          'request_timeout_seconds', (dc.deployment_mechanism->>'request_timeout_seconds')::int,
          'max_in_progress_operations', (dc.deployment_mechanism->>'max_in_progress_deployments')::int
        )
      ),
      dc.start_timestamp,
      dc.completion_timestamp,
      dc.inserted_at,
      dc.updated_at,
      dc.tenant_id,
      dc.channel_id
    FROM deployment_campaigns dc
    """

    # Migrate deployment_targets to campaign_targets
    execute """
    INSERT INTO campaign_targets (
      id,
      status,
      retry_count,
      latest_attempt,
      completion_timestamp,
      inserted_at,
      updated_at,
      tenant_id,
      campaign_id,
      device_id,
      deployment_id,
      ota_operation_id
    )
    SELECT
      dt.id,
      dt.status,
      dt.retry_count,
      dt.latest_attempt,
      dt.completion_timestamp,
      dt.inserted_at,
      dt.updated_at,
      dt.tenant_id,
      dt.deployment_campaign_id,
      dt.device_id,
      dt.deployment_id,
      NULL
    FROM deployment_targets dt
    """

    # Create a temporary mapping table to track old update_campaign int IDs to new campaign UUIDs
    execute """
    CREATE TEMPORARY TABLE update_campaign_id_mapping (
      old_id bigint PRIMARY KEY,
      new_id uuid NOT NULL
    )
    """

    # Migrate update_campaigns to campaigns
    execute """
    INSERT INTO update_campaign_id_mapping (old_id, new_id)
    SELECT id, gen_random_uuid()
    FROM update_campaigns
    """

    # Insert update_campaigns into campaigns with the new UUIDs
    execute """
    INSERT INTO campaigns (
      id,
      name,
      status,
      outcome,
      campaign_mechanism,
      start_timestamp,
      completion_timestamp,
      inserted_at,
      updated_at,
      tenant_id,
      channel_id
    )
    SELECT
      temp.new_id,
      uc.name,
      uc.status,
      uc.outcome,
      jsonb_build_object(
        'type', 'firmware_upgrade',
        'base_image_id', uc.base_image_id,
        'force_downgrade', (uc.rollout_mechanism->>'force_downgrade')::boolean,
        'request_retries', (uc.rollout_mechanism->>'ota_request_retries')::int,
        'max_failure_percentage', (uc.rollout_mechanism->>'max_failure_percentage')::float,
        'request_timeout_seconds', (uc.rollout_mechanism->>'ota_request_timeout_seconds')::int,
        'max_in_progress_operations', (uc.rollout_mechanism->>'max_in_progress_updates')::int
      ),
      uc.start_timestamp,
      uc.completion_timestamp,
      uc.inserted_at,
      uc.updated_at,
      uc.tenant_id,
      uc.channel_id
    FROM update_campaigns uc
    JOIN update_campaign_id_mapping temp ON uc.id = temp.old_id
    """

    # Migrate update_campaign_targets to campaign_targets
    execute """
    INSERT INTO campaign_targets (
      id,
      status,
      retry_count,
      latest_attempt,
      completion_timestamp,
      inserted_at,
      updated_at,
      tenant_id,
      campaign_id,
      device_id,
      deployment_id,
      ota_operation_id
    )
    SELECT
      gen_random_uuid(),
      uct.status,
      uct.retry_count,
      uct.latest_attempt,
      uct.completion_timestamp,
      uct.inserted_at,
      uct.updated_at,
      uct.tenant_id,
      temp.new_id,
      uct.device_id,
      NULL,
      uct.ota_operation_id
    FROM update_campaign_targets uct
    JOIN update_campaign_id_mapping temp ON uct.update_campaign_id = temp.old_id
    """

    # Clean up temporary mapping table
    execute "DROP TABLE update_campaign_id_mapping"

    # Step 4: Drop legacy tables
    drop table(:update_campaign_targets)
    drop table(:deployment_targets)
    drop table(:update_campaigns)
    drop table(:deployment_campaigns)

    # Fix residue from previous migrations
    drop_if_exists table(:deployment_channels)

    # Rename channels primary key constraint if needed
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'update_channels_pkey'
        AND conrelid = 'channels'::regclass
      ) THEN
        ALTER TABLE channels RENAME CONSTRAINT update_channels_pkey TO channels_pkey;
      END IF;
    END $$;
    """
  end

  def down do
    # Step 1: We wont recreate deployment_channels table here as it was not being used
    # The migration only dropped it to fix residue from previous migrations.
    # The original migration that made deployment_channels redundant should be updated.
    # Same for the channels primary key constraint changes.

    # Step 2: Recreate update_campaigns table
    create table(:update_campaigns) do
      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "update_campaigns_tenant_id_fkey",
            on_delete: :delete_all
          ),
          null: false

      add :channel_id,
          references(:channels,
            with: [tenant_id: :tenant_id],
            match: :full,
            name: "update_campaigns_channel_id_fkey",
            on_delete: :nothing
          ),
          null: false

      add :base_image_id,
          references(:base_images,
            with: [tenant_id: :tenant_id],
            match: :full,
            name: "update_campaigns_base_image_id_fkey",
            on_delete: :nothing
          ),
          null: false

      add :name, :text, null: false
      add :status, :text, null: false
      add :outcome, :text
      add :rollout_mechanism, :map, null: false
      add :start_timestamp, :utc_datetime_usec
      add :completion_timestamp, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:update_campaigns, [:id, :tenant_id])
    create index(:update_campaigns, [:tenant_id])
    create index(:update_campaigns, [:base_image_id, :tenant_id])
    create index(:update_campaigns, [:channel_id, :tenant_id])

    # Step 3: Recreate deployment_campaigns table
    create table(:deployment_campaigns, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :status, :text, null: false
      add :outcome, :text
      add :deployment_mechanism, :map, null: false
      add :operation_type, :text, null: false, default: "deploy"
      add :start_timestamp, :utc_datetime_usec
      add :completion_timestamp, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "deployment_campaigns_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :release_id,
          references(:application_releases,
            column: :id,
            name: "deployment_campaigns_release_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :target_release_id,
          references(:application_releases,
            column: :id,
            name: "deployment_campaigns_target_release_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :channel_id,
          references(:channels,
            column: :id,
            with: [tenant_id: :tenant_id],
            match: :full,
            name: "deployment_campaigns_channel_id_fkey",
            type: :integer,
            prefix: "public",
            on_delete: :nothing
          ),
          null: false
    end

    create index(:deployment_campaigns, [:tenant_id])
    create index(:deployment_campaigns, [:id, :tenant_id], unique: true)
    create index(:deployment_campaigns, [:tenant_id, :channel_id])

    # Step 4: Recreate update_campaign_targets table
    create table(:update_campaign_targets) do
      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "update_campaign_targets_tenant_id_fkey",
            on_delete: :delete_all
          ),
          null: false

      add :status, :text, null: false
      add :retry_count, :bigint, null: false, default: 0
      add :latest_attempt, :utc_datetime_usec
      add :completion_timestamp, :utc_datetime_usec

      add :update_campaign_id,
          references(:update_campaigns,
            with: [tenant_id: :tenant_id],
            match: :full,
            name: "update_campaign_targets_update_campaign_id_fkey",
            on_delete: :delete_all
          ),
          null: false

      add :device_id,
          references(:devices,
            with: [tenant_id: :tenant_id],
            match: :full,
            name: "update_campaign_targets_device_id_fkey",
            on_delete: :nothing
          ),
          null: false

      add :ota_operation_id,
          references(:ota_operations,
            with: [tenant_id: :tenant_id],
            match: :simple,
            name: "update_campaign_targets_ota_operation_id_fkey",
            type: :uuid,
            on_delete: :nothing
          )

      timestamps(type: :utc_datetime_usec)
    end

    create index(:update_campaign_targets, [:tenant_id])
    create unique_index(:update_campaign_targets, [:id, :tenant_id])
    create index(:update_campaign_targets, [:device_id])
    create index(:update_campaign_targets, [:update_campaign_id])
    create unique_index(:update_campaign_targets, [:update_campaign_id, :device_id, :tenant_id])

    # Step 5: Recreate deployment_targets table
    create table(:deployment_targets, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :status, :text, null: false
      add :retry_count, :bigint, null: false, default: 0
      add :latest_attempt, :utc_datetime_usec
      add :completion_timestamp, :utc_datetime_usec

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :tenant_id,
          references(:tenants,
            column: :tenant_id,
            name: "deployment_targets_tenant_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :deployment_campaign_id,
          references(:deployment_campaigns,
            column: :id,
            name: "deployment_targets_deployment_campaign_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :device_id,
          references(:devices,
            column: :id,
            name: "deployment_targets_device_id_fkey",
            type: :bigint,
            prefix: "public",
            on_delete: :delete_all
          ),
          null: false

      add :deployment_id,
          references(:application_deployments,
            column: :id,
            name: "deployment_targets_deployment_id_fkey",
            type: :uuid,
            prefix: "public",
            on_delete: :nilify_all
          )
    end

    create index(:deployment_targets, [:tenant_id])
    create index(:deployment_targets, [:id, :tenant_id], unique: true)

    # Step 6: Migrate data back from unified tables to legacy tables

    # Create a temporary mapping table to track campaign UUIDs to new update_campaign int IDs
    execute """
    CREATE TEMPORARY TABLE campaign_to_update_campaign_mapping (
      campaign_id uuid PRIMARY KEY,
      update_campaign_id bigint NOT NULL
    )
    """

    # Migrate campaigns with firmware_upgrade type back to update_campaigns
    execute """
    INSERT INTO update_campaigns (
      name,
      status,
      outcome,
      rollout_mechanism,
      start_timestamp,
      completion_timestamp,
      inserted_at,
      updated_at,
      tenant_id,
      channel_id,
      base_image_id
    )
    SELECT
      c.name,
      c.status,
      c.outcome,
      jsonb_build_object(
        'force_downgrade', (c.campaign_mechanism->>'force_downgrade')::boolean,
        'ota_request_retries', (c.campaign_mechanism->>'request_retries')::int,
        'max_failure_percentage', (c.campaign_mechanism->>'max_failure_percentage')::float,
        'ota_request_timeout_seconds', (c.campaign_mechanism->>'request_timeout_seconds')::int,
        'max_in_progress_updates', (c.campaign_mechanism->>'max_in_progress_operations')::int
      ),
      c.start_timestamp,
      c.completion_timestamp,
      c.inserted_at,
      c.updated_at,
      c.tenant_id,
      c.channel_id,
      (c.campaign_mechanism->>'base_image_id')::bigint
    FROM campaigns c
    WHERE c.campaign_mechanism->>'type' = 'firmware_upgrade'
    """

    # Populate the mapping table
    execute """
    INSERT INTO campaign_to_update_campaign_mapping (campaign_id, update_campaign_id)
    SELECT c.id, uc.id
    FROM campaigns c
    JOIN update_campaigns uc ON
      uc.name = c.name AND
      uc.tenant_id = c.tenant_id AND
      uc.inserted_at = c.inserted_at
    WHERE c.campaign_mechanism->>'type' = 'firmware_upgrade'
    """

    # Migrate campaign_targets for firmware_upgrade campaigns to update_campaign_targets
    execute """
    INSERT INTO update_campaign_targets (
      status,
      retry_count,
      latest_attempt,
      completion_timestamp,
      inserted_at,
      updated_at,
      tenant_id,
      update_campaign_id,
      device_id,
      ota_operation_id
    )
    SELECT
      ct.status,
      ct.retry_count,
      ct.latest_attempt,
      ct.completion_timestamp,
      ct.inserted_at,
      ct.updated_at,
      ct.tenant_id,
      mapping.update_campaign_id,
      ct.device_id,
      ct.ota_operation_id
    FROM campaign_targets ct
    JOIN campaigns c ON ct.campaign_id = c.id
    JOIN campaign_to_update_campaign_mapping mapping ON ct.campaign_id = mapping.campaign_id
    WHERE c.campaign_mechanism->>'type' = 'firmware_upgrade'
      AND ct.deployment_id IS NULL
    """

    # Clean up temporary mapping table
    execute "DROP TABLE campaign_to_update_campaign_mapping"

    # Migrate campaigns with deployment types back to deployment_campaigns
    execute """
    INSERT INTO deployment_campaigns (
      id,
      name,
      status,
      outcome,
      deployment_mechanism,
      operation_type,
      start_timestamp,
      completion_timestamp,
      inserted_at,
      updated_at,
      tenant_id,
      channel_id,
      release_id,
      target_release_id
    )
    SELECT
      c.id,
      c.name,
      c.status,
      c.outcome,
      jsonb_build_object(
        'create_request_retries', (c.campaign_mechanism->>'request_retries')::int,
        'max_failure_percentage', (c.campaign_mechanism->>'max_failure_percentage')::float,
        'request_timeout_seconds', (c.campaign_mechanism->>'request_timeout_seconds')::int,
        'max_in_progress_deployments', (c.campaign_mechanism->>'max_in_progress_operations')::int
      ),
      CASE c.campaign_mechanism->>'type'
        WHEN 'deployment_deploy'  THEN 'deploy'
        WHEN 'deployment_start'   THEN 'start'
        WHEN 'deployment_stop'    THEN 'stop'
        WHEN 'deployment_upgrade' THEN 'upgrade'
        WHEN 'deployment_delete'  THEN 'delete'
        ELSE 'deploy'
      END,
      c.start_timestamp,
      c.completion_timestamp,
      c.inserted_at,
      c.updated_at,
      c.tenant_id,
      c.channel_id,
      (c.campaign_mechanism->>'release_id')::uuid,
      (c.campaign_mechanism->>'target_release_id')::uuid
    FROM campaigns c
    WHERE c.campaign_mechanism->>'type' IN (
      'deployment_deploy', 'deployment_start', 'deployment_stop',
      'deployment_upgrade', 'deployment_delete'
    )
    """

    # Migrate campaign_targets for deployment campaigns to deployment_targets
    execute """
    INSERT INTO deployment_targets (
      id,
      status,
      retry_count,
      latest_attempt,
      completion_timestamp,
      inserted_at,
      updated_at,
      tenant_id,
      deployment_campaign_id,
      device_id,
      deployment_id
    )
    SELECT
      ct.id,
      ct.status,
      ct.retry_count,
      ct.latest_attempt,
      ct.completion_timestamp,
      ct.inserted_at,
      ct.updated_at,
      ct.tenant_id,
      ct.campaign_id,
      ct.device_id,
      ct.deployment_id
    FROM campaign_targets ct
    JOIN campaigns c ON ct.campaign_id = c.id
    WHERE c.campaign_mechanism->>'type' IN (
      'deployment_deploy', 'deployment_start', 'deployment_stop',
      'deployment_upgrade', 'deployment_delete'
    )
    """

    # Step 7: Drop the unified tables
    execute """
    ALTER TABLE campaign_targets
    DROP CONSTRAINT IF EXISTS campaign_targets_deployment_id_fkey
    """

    execute """
    ALTER TABLE campaign_targets
    DROP CONSTRAINT IF EXISTS campaign_targets_ota_operation_id_fkey
    """

    drop constraint(:campaign_targets, "campaign_targets_tenant_id_fkey")
    drop constraint(:campaign_targets, "campaign_targets_campaign_id_fkey")
    drop constraint(:campaign_targets, "campaign_targets_device_id_fkey")
    drop_if_exists index(:campaign_targets, [:id, :tenant_id])
    drop_if_exists index(:campaign_targets, [:tenant_id])
    drop table(:campaign_targets)

    drop constraint(:campaigns, "campaigns_tenant_id_fkey")
    drop constraint(:campaigns, "campaigns_channel_id_fkey")
    drop_if_exists index(:campaigns, [:tenant_id, :channel_id])
    drop_if_exists index(:campaigns, [:id, :tenant_id])
    drop_if_exists index(:campaigns, [:tenant_id])
    drop table(:campaigns)
  end
end
