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

defmodule Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade do
  @moduledoc """
  Defines the Firmware Upgrade Campaign Mechanism resource.
  This resource represents the configuration for a firmware upgrade operation within a firmware upgrade campaign.
  """

  use Ash.Resource,
    extensions: [
      AshGraphql.Resource
    ],
    data_layer: :embedded

  resource do
    description """
    An object representing the properties of a Firmware Upgrade campaign mechanism.
    """
  end

  graphql do
    type :firmware_upgrade
  end

  attributes do
    attribute :type, :atom do
      description """
      The type of rollout.

      This field is used to distinguish this rollout from other types of rollout.
      """

      constraints one_of: [:firmware_upgrade]
      allow_nil? false
      default :firmware_upgrade
    end

    attribute :force_downgrade, :boolean do
      description """
      This boolean flag determines if the Base Image will be pushed to the
      Device even if it already has a greater version of the Base Image.
      """

      public? true
      allow_nil? false
      default false
    end

    attribute :max_failure_percentage, :float do
      description """
      The maximum percentage of failures allowed over the number of total targets.
      If the failures exceed this threshold, the Update Campaign terminates with
      a failure.
      """

      public? true
      allow_nil? false
      constraints min: 0, max: 100
    end

    attribute :max_in_progress_operations, :integer do
      description """
      The maximum number of in progress updates. The Update Campaign will have
      at most this number of OTA Operations that are started but not yet
      finished (either successfully or not).
      """

      public? true
      allow_nil? false
      constraints min: 1
    end

    attribute :request_retries, :integer do
      description """
      The number of attempts that have to be tried before giving up on the
      update of a specific target (and considering it an error). Note that the
      update is retried only if the OTA Request doesn't get acknowledged from the
      device.
      """

      public? true
      allow_nil? false
      default 3
      constraints min: 0
    end

    attribute :request_timeout_seconds, :integer do
      description """
      The timeout (in seconds) Edgehog has to wait before considering an OTA
      Request lost (and possibly retry). It must be at least 30 seconds.
      """

      public? true
      allow_nil? false
      default 300
      constraints min: 30
    end
  end

  relationships do
    belongs_to :base_image, Edgehog.BaseImages.BaseImage do
      description "The base image distributed by the update campaign."
      public? true
      attribute_type :id
    end
  end
end
