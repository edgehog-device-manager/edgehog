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

defmodule Edgehog.Repo.Migrations.RenameDeploymentTablesToPlural do
  @moduledoc """
  Renames deployment tables to follow the plural naming convention.

  This migration renames existing tables instead of creating new ones:
  - deployment_target -> deployment_targets
  - deployment_campaign -> deployment_campaigns
  """

  use Ecto.Migration

  def up do
    # Rename regular tables
    rename table(:deployment_target), to: table(:deployment_targets)
    rename table(:deployment_campaign), to: table(:deployment_campaigns)

    # Rename constraints for deployment_target -> deployment_targets
    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_target_tenant_id_fkey TO deployment_targets_tenant_id_fkey"

    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_target_deployment_campaign_id_fkey TO deployment_targets_deployment_campaign_id_fkey"

    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_target_device_id_fkey TO deployment_targets_device_id_fkey"

    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_target_deployment_id_fkey TO deployment_targets_deployment_id_fkey"

    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_target_pkey TO deployment_targets_pkey"

    # Rename constraints for deployment_campaign -> deployment_campaigns
    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaign_tenant_id_fkey TO deployment_campaigns_tenant_id_fkey"

    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaign_release_id_fkey TO deployment_campaigns_release_id_fkey"

    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaign_channel_id_fkey TO deployment_campaigns_channel_id_fkey"

    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaign_target_release_id_fkey TO deployment_campaigns_target_release_id_fkey"

    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaign_pkey TO deployment_campaigns_pkey"

    # Rename indexes for deployment_targets
    execute "ALTER INDEX deployment_target_tenant_id_index RENAME TO deployment_targets_tenant_id_index"

    execute "ALTER INDEX deployment_target_id_tenant_id_index RENAME TO deployment_targets_id_tenant_id_index"

    # Rename indexes for deployment_campaigns
    execute "ALTER INDEX deployment_campaign_tenant_id_index RENAME TO deployment_campaigns_tenant_id_index"

    execute "ALTER INDEX deployment_campaign_id_tenant_id_index RENAME TO deployment_campaigns_id_tenant_id_index"

    execute "ALTER INDEX deployment_campaign_tenant_id_channel_id_index RENAME TO deployment_campaigns_tenant_id_channel_id_index"
  end

  def down do
    # Revert index names for deployment_campaigns
    execute "ALTER INDEX deployment_campaigns_tenant_id_channel_id_index RENAME TO deployment_campaign_tenant_id_channel_id_index"

    execute "ALTER INDEX deployment_campaigns_id_tenant_id_index RENAME TO deployment_campaign_id_tenant_id_index"

    execute "ALTER INDEX deployment_campaigns_tenant_id_index RENAME TO deployment_campaign_tenant_id_index"

    # Revert index names for deployment_targets
    execute "ALTER INDEX deployment_targets_id_tenant_id_index RENAME TO deployment_target_id_tenant_id_index"

    execute "ALTER INDEX deployment_targets_tenant_id_index RENAME TO deployment_target_tenant_id_index"

    # Revert constraint names for deployment_campaigns
    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaigns_pkey TO deployment_campaign_pkey"

    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaigns_target_release_id_fkey TO deployment_campaign_target_release_id_fkey"

    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaigns_channel_id_fkey TO deployment_campaign_channel_id_fkey"

    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaigns_release_id_fkey TO deployment_campaign_release_id_fkey"

    execute "ALTER TABLE deployment_campaigns RENAME CONSTRAINT deployment_campaigns_tenant_id_fkey TO deployment_campaign_tenant_id_fkey"

    # Revert constraint names for deployment_targets
    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_targets_pkey TO deployment_target_pkey"

    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_targets_deployment_id_fkey TO deployment_target_deployment_id_fkey"

    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_targets_device_id_fkey TO deployment_target_device_id_fkey"

    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_targets_deployment_campaign_id_fkey TO deployment_target_deployment_campaign_id_fkey"

    execute "ALTER TABLE deployment_targets RENAME CONSTRAINT deployment_targets_tenant_id_fkey TO deployment_target_tenant_id_fkey"

    # Revert regular tables
    rename table(:deployment_campaigns), to: table(:deployment_campaign)
    rename table(:deployment_targets), to: table(:deployment_target)
  end
end
