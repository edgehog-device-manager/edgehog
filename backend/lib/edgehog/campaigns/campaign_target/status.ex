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

defmodule Edgehog.Campaigns.CampaignTarget.Status do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      idle: "The campaign target is waiting for the campaign to start.",
      in_progress: "The campaign is in progress.",
      failed: "Something went wrong while attempting operation on the target.",
      successful: "The operation has executed successfully on the target."
    ]

  def graphql_type(_), do: :campaign_target_status
end
