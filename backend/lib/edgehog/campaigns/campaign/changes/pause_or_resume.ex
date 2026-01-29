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

defmodule Edgehog.Campaigns.Campaign.Changes.PauseOrResume do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Edgehog.Campaigns.ExecutorSupervisor

  @impl Ash.Resource.Change
  def change(changeset, opts, _context) do
    operation = Keyword.fetch!(opts, :operation)

    changeset
    |> validate_transition(operation)
    |> apply_status_change(operation)
    |> maybe_dispatch_after_transaction(operation)
  end

  defp validate_transition(changeset, :pause) do
    case Changeset.get_data(changeset, :status) do
      :in_progress ->
        changeset

      _other ->
        Changeset.add_error(changeset,
          field: :status,
          message: "Campaign can be paused only while in progress"
        )
    end
  end

  defp validate_transition(changeset, :resume) do
    case Changeset.get_data(changeset, :status) do
      :paused ->
        changeset

      _other ->
        Changeset.add_error(changeset,
          field: :status,
          message: "Campaign can be resumed only when paused"
        )
    end
  end

  defp apply_status_change(%Changeset{valid?: false} = changeset, _operation), do: changeset

  defp apply_status_change(changeset, :pause) do
    Changeset.change_attribute(changeset, :status, :paused)
  end

  defp apply_status_change(changeset, :resume) do
    Changeset.change_attribute(changeset, :status, :in_progress)
  end

  defp maybe_dispatch_after_transaction(%Changeset{valid?: false} = changeset, _operation), do: changeset

  defp maybe_dispatch_after_transaction(changeset, operation) do
    Changeset.after_transaction(changeset, fn _changeset, result ->
      case result do
        {:ok, campaign} ->
          dispatch_to_executor(operation, campaign)
          {:ok, campaign}

        other ->
          other
      end
    end)
  end

  defp dispatch_to_executor(:pause, campaign), do: ExecutorSupervisor.pause_executor!(campaign)
  defp dispatch_to_executor(:resume, campaign), do: ExecutorSupervisor.resume_executor!(campaign)
end
