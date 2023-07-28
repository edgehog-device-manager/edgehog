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

defmodule Edgehog.UpdateCampaigns.Resumer.Core do
  import Ecto.Query
  alias Edgehog.Repo
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  @doc """
  Returns a stream of all resumable update campaigns.
  """
  def stream_resumable_update_campaigns do
    query =
      from u in UpdateCampaign,
        where: u.status in [:idle, :in_progress]

    # We stream the result so we don't have to load all the update campaigns in memory at once
    Repo.stream(query, skip_tenant_id: true)
  end

  @doc """
  Executes `fun` for each Update Campaign contained in `stream`.

  The stream is unrolled in a transaction as required by Ecto docs.
  """
  def for_each_update_campaign(stream, fun) when is_function(fun, 1) do
    {:ok, _} = Repo.transaction(fn -> Enum.each(stream, fun) end)

    :ok
  end
end
