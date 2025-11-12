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

defmodule Edgehog.Campaigns.Executors.Core do
  @moduledoc """
  Defines the behavior that campaign-specific Core modules must implement.

  This behavior separates generic campaign execution logic from campaign-specific
  business logic. By implementing this behavior, you can use the generic
  `Edgehog.Campaigns.Executors.LazyBatch` executor for your campaign type.
  """

  # Campaign Management
  @callback get_campaign!(tenant_id :: String.t(), campaign_id :: String.t()) :: struct()
  @callback get_mechanism(campaign :: struct()) :: struct()
  @callback get_campaign_status(campaign :: struct()) :: :idle | :in_progress | :finished
  @callback load_campaign_data(tenant_id :: String.t(), campaign :: struct()) :: map()
  @callback mark_campaign_in_progress!(campaign :: struct()) :: struct()
  @callback mark_campaign_as_failed!(campaign :: struct()) :: struct()
  @callback mark_campaign_as_successful!(campaign :: struct()) :: struct()

  # Target Management
  @callback fetch_next_valid_target(
              tenant_id :: String.t(),
              campaign_id :: String.t(),
              campaign_data :: map()
            ) :: {:ok, struct()} | {:error, term()}
  @callback get_target!(tenant_id :: String.t(), target_id :: String.t()) :: struct()
  @callback get_target_for_operation!(
              tenant_id :: String.t(),
              campaign_id :: String.t(),
              device_id :: String.t()
            ) :: struct()
  @callback get_operation_id(target :: struct()) :: String.t()
  @callback mark_target_as_failed!(target :: struct()) :: struct()
  @callback mark_target_as_successful!(target :: struct()) :: struct()

  # Metrics and Monitoring
  @callback get_target_count(tenant_id :: String.t(), campaign_id :: String.t()) :: integer()
  @callback get_failed_target_count(tenant_id :: String.t(), campaign_id :: String.t()) ::
              integer()
  @callback get_in_progress_target_count(tenant_id :: String.t(), campaign_id :: String.t()) ::
              integer()
  @callback available_slots(mechanism :: struct(), in_progress_count :: integer()) :: integer()
  @callback has_idle_targets?(tenant_id :: String.t(), campaign_id :: String.t()) :: boolean()
  @callback list_in_progress_targets(tenant_id :: String.t(), campaign_id :: String.t()) :: [
              struct()
            ]

  # Retry Logic
  @callback can_retry?(target :: struct(), mechanism :: struct()) :: boolean()
  @callback increase_retry_count!(target :: struct()) :: struct()
  @callback update_target_latest_attempt!(target :: struct(), timestamp :: DateTime.t()) ::
              struct()
  @callback pending_request_timeout_ms(target :: struct(), mechanism :: struct()) :: integer()

  # Operation Execution
  @callback do_operation(
              target :: struct(),
              campaign_data :: map(),
              mechanism :: struct()
            ) :: {:ok, struct()} | {:ok, :already_in_desired_state} | {:error, term()}
  @callback retry_operation(target :: struct(), campaign_data :: map()) :: :ok | {:error, term()}
  @callback subscribe_to_operation_updates!(operation_id :: String.t()) :: :ok
  @callback unsubscribe_to_operation_updates!(operation_id :: String.t()) :: :ok
  @callback mark_operation_as_timed_out!(
              tenant_id :: String.t(),
              operation_id :: String.t()
            ) :: struct()

  # Error Handling
  @callback temporary_error?(reason :: term()) :: boolean()
  @callback error_message(reason :: term(), device_id :: String.t()) :: String.t()
  @callback format_operation_failure_log(operation :: struct(), campaign_data :: map()) :: :ok

  # Optional Callbacks
  @callback failure_threshold_exceeded?(
              target_count :: integer(),
              failed_count :: integer(),
              mechanism :: struct()
            ) :: boolean()

  @doc """
  Default implementation for failure threshold check.
  """
  def failure_threshold_exceeded?(target_count, failed_count, mechanism) do
    failed_count / target_count * 100 > mechanism.max_failure_percentage
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Edgehog.Campaigns.Executors.Core

      defdelegate failure_threshold_exceeded?(target_count, failed_count, mechanism),
        to: Edgehog.Campaigns.Executors.Core

      defoverridable failure_threshold_exceeded?: 3
    end
  end
end
