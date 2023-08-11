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
    max_failure_percentage: 0,
    max_in_progress_updates: 1,
    ota_request_retries: 0,
    ota_request_timeout_seconds: 30
  ]

  @primary_key false
  embedded_schema do
    field :force_downgrade, :boolean, default: false
    field :max_failure_percentage, :float
    field :max_in_progress_updates, :integer
    field :ota_request_retries, :integer, default: 0
    field :ota_request_timeout_seconds, :integer, default: 60
  end

  @doc false
  def changeset(%PushRollout{} = push_rollout, attrs) do
    push_rollout
    |> cast(attrs, [
      :force_downgrade,
      :max_failure_percentage,
      :max_in_progress_updates,
      :ota_request_retries,
      :ota_request_timeout_seconds
    ])
    |> validate_required([
      :max_failure_percentage,
      :max_in_progress_updates
    ])
    |> validate_minimums(push_rollout, @changeset_minimums)
    |> validate_number(:max_failure_percentage, less_than_or_equal_to: 100)
  end

  defp validate_minimums(changeset, base, default_minimums) do
    %{minimums: minimums, error_message: error_message} =
      minimum_parameters_for(base, default_minimums)

    Enum.reduce(minimums, changeset, &validate_min(&2, &1, error_message))
  end

  defp validate_min(changeset, {field, minimum}, error_message) do
    validate_number(changeset, field, greater_than_or_equal_to: minimum, message: error_message)
  end

  defp minimum_parameters_for(base, default_minimums) do
    if was_default?(base) do
      %{
        minimums: default_minimums,
        error_message: "must be greater than or equal to %{number}"
      }
    else
      keys = Keyword.keys(default_minimums)
      values_from_base = Map.take(base, keys)

      %{
        minimums: values_from_base,
        error_message: "must be greater than or equal to its previous value, %{number}"
      }
    end
  end

  defp was_default?(base) do
    # PushRollouts cannot have nil :max_failure_percentage and :max_in_progress_updates
    # under normal circumstances as they are required in the changeset,
    # but it is their default value for the struct.
    # We use this piece of information to infer whether we're updating an existing struct
    # or defining a new one.
    base == %PushRollout{}
  end
end
