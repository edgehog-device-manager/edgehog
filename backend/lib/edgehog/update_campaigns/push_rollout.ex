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

defmodule Edgehog.UpdateCampaigns.PushRollout do
  use Ecto.Schema
  import Ecto.Changeset
  alias Edgehog.UpdateCampaigns.PushRollout

  @changeset_minimums [
    max_errors_percentage: 0,
    max_in_progress_updates: 1,
    ota_request_retries: 0,
    ota_request_timeout_seconds: 30
  ]

  @primary_key false
  embedded_schema do
    field :force_downgrade, :boolean, default: false
    field :max_errors_percentage, :float
    field :max_in_progress_updates, :integer
    field :ota_request_retries, :integer, default: 0
    field :ota_request_timeout_seconds, :integer, default: 60
  end

  @doc false
  def create_changeset(%PushRollout{} = push_rollout, attrs) do
    do_changeset(push_rollout, attrs, fetch_existing_min: &to_nil/2)
  end

  @doc false
  def changeset(%PushRollout{} = push_rollout, attrs) do
    do_changeset(push_rollout, attrs)
  end

  defp do_changeset(push_rollout, attrs, opts \\ []) do
    fetch_existing_min = Keyword.get(opts, :fetch_existing_min, &fetch_minimum/2)

    push_rollout
    |> cast(attrs, [
      :force_downgrade,
      :max_errors_percentage,
      :max_in_progress_updates,
      :ota_request_retries,
      :ota_request_timeout_seconds
    ])
    |> validate_required([
      :max_errors_percentage,
      :max_in_progress_updates
    ])
    |> validate_minimums(push_rollout, fetch_existing_min, @changeset_minimums)
    |> validate_number(:max_errors_percentage, less_than_or_equal_to: 100)
  end

  defp validate_minimums(changeset, base, fetch_existing_min, minimums) do
    Enum.reduce(minimums, changeset, &validate_min(&2, &1, base, fetch_existing_min))
  end

  defp validate_min(changeset, {field, default_min}, base, fetch_existing_min) do
    new_min = fetch_existing_min.(base, field) || default_min
    validate_number(changeset, field, greater_than_or_equal_to: new_min)
  end

  defp to_nil(_, _), do: nil
  defp fetch_minimum(base, field), do: get_in(base, [Access.key!(field)])
end
