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

defprotocol Edgehog.Campaigns.CampaignMechanism.Core do
  @moduledoc """
  Protocol defining the core functions that a campaign mechanism must implement.

  These functions cover the essential operations needed to manage and execute campaigns,
  including operation tracking, target management, and notification handling.
  """

  def get_operation_id(mechanism, target)

  def mark_operation_as_timed_out!(mechanism, operation_id, tenant_id)

  def subscribe_to_operation_updates!(mechanism, operation_id)

  def unsubscribe_to_operation_updates!(mechanism, operation_id)

  def fetch_next_valid_target(mechanism, campaign_id, tenant_id)

  def do_operation(mechanism, target)

  def retry_operation(mechanism, target)

  def get_mechanism(mechanism, campaign)
end
