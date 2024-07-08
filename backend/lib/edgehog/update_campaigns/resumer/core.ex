#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.Resumer.Core do
  @moduledoc false
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  require Ash.Query

  @doc """
  Returns a stream of all resumable update campaigns.
  """
  def stream_resumable_update_campaigns do
    # We stream the result so we don't have to load all the update campaigns in memory at once
    UpdateCampaign
    |> Ash.Query.for_read(:read_all_resumable)
    |> Ash.stream!()
  end
end
