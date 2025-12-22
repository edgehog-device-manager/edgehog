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

defmodule Edgehog.Campaigns.CampaignMechanism.DeploymentUpgrade do
  @moduledoc """
  Defines the Upgrade Campaign Mechanism resource.
  This resource represents the configuration for an upgrade operation within a deployment campaign.
  """

  use Ash.Resource,
    extensions: [
      AshGraphql.Resource
    ],
    data_layer: :embedded

  alias Edgehog.Containers.Release

  resource do
    description """
    An object representing the properties of a Upgrade deployment campaign mechanism.
    """
  end

  graphql do
    type :deployment_upgrade
  end

  attributes do
    attribute :type, :atom do
      description """
      The type of rollout.

      This field is used to distinguish this mechanism from others.
      """

      constraints one_of: [:deployment_upgrade]
      allow_nil? false
      default :deployment_upgrade
    end

    # TODO add a `allow_downgrade` attribute to allow the downgrade of existing
    # releases on targeted devices.

    attribute :max_failure_percentage, :float do
      description """
      The maximum percentage of failures allowed over the number of total targets.
      If the failures exceed this threshold, the Campaign terminates with
      a failure.
      """

      public? true
      allow_nil? false
      constraints min: 0, max: 100
    end

    attribute :max_in_progress_operations, :integer do
      description """
      The maximum number of in progress operations. The Campaign will
      have at most this number of Deployments that are started but not yet
      finished (either successfully or not).
      """

      public? true
      allow_nil? false
      constraints min: 1
    end

    # TODO create_request and timeouts can be per-resource specified. this first
    # approach is to make it general.

    attribute :request_retries, :integer do
      description """
      The number of attempts that have to be tried before giving up on the
      deploy of a specific target (and considering it an error). Note that the
      deployment is retried only if the Deployment doesn't get acknowledged from the
      device.
      """

      public? true
      allow_nil? false
      default 3
      constraints min: 0
    end

    attribute :request_timeout_seconds, :integer do
      description """
      The timeout (in seconds) Edgehog has to wait before considering a
      Deployment lost (and possibly retry). It must be at least 30 seconds.
      """

      public? true
      allow_nil? false
      default 300
      constraints min: 30
    end
  end

  relationships do
    belongs_to :release, Release do
      description "The release deployed by the mechanism."
      public? true
      attribute_type :uuid
    end

    belongs_to :target_release, Release do
      description "The release used for upgrading by the deployment campaign."
      public? true
      attribute_type :uuid
    end
  end
end
