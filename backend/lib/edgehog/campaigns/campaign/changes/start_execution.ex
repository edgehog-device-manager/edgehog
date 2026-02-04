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

defmodule Edgehog.Campaigns.Campaign.Changes.StartExecution do
  @moduledoc false

  use Ash.Resource.Change

  alias Edgehog.Campaigns.ExecutorSupervisor

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.change_attribute(:status, :in_progress)
    |> Ash.Changeset.after_transaction(fn _changeset, result ->
      start_campaign_executor(result)
    end)
  end

  defp start_campaign_executor({:ok, campaign} = _transaction_result) do
    _pid = ExecutorSupervisor.start_executor!(campaign)

    {:ok, campaign}
  end

  defp start_campaign_executor(transaction_result), do: transaction_result
end
