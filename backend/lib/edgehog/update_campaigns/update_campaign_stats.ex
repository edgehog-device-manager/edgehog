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

defmodule Edgehog.UpdateCampaigns.UpdateCampaignStats do
  use TypedStruct

  @typedoc "A struct representing Update Campaign stats"
  typedstruct enforce: true do
    field :total_target_count, non_neg_integer()
    field :idle_target_count, non_neg_integer()
    field :in_progress_target_count, non_neg_integer()
    field :failed_target_count, non_neg_integer()
    field :successful_target_count, non_neg_integer()
  end
end
