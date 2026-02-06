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

defmodule Edgehog.Campaigns.CampaignMechanism.FirmwareUpgrade.Executor do
  @moduledoc """
  Executor for lazy deployment campaigns using the generic LazyBatch behavior.

  """
  use Edgehog.Campaigns.Executors.Lazy.LazyBatch

  alias Edgehog.Campaigns.Executors.Lazy.LazyBatch

  require Logger

  @impl LazyBatch
  def handle_info(:start_execution, :wait_for_start_execution, data) do
    {:next_state, :initialization, data, internal_event(:init_data)}
  end

  # Valid states from which pausing is allowed
  @pauseable_states [
    :execution,
    :wait_for_available_slot,
    :wait_for_target,
    :wait_for_campaign_completion
  ]

  # Common event handling

  # Note that external (e.g. :info) and timeout events are always handled after the internal
  # events enqueued with the :next_event action. This means that we can be sure an :info event
  # or a timeout won't be handled, e.g., between a rollout and the handling of its error
  @impl LazyBatch
  def handle_info(%Phoenix.Socket.Broadcast{} = notification, state, data) do
    case notification.payload.action.type do
      :update -> handle_update(notification, state, data)
      _ -> :keep_state_and_data
    end
  end

  def handle_info(_message, _state, _data) do
    # Ignore any other messages
    :keep_state_and_data
  end

  defp handle_update(notification, state, data) do
    case notification.payload.action.name do
      :update_status -> handle_update_status(notification, data)
      :pause -> handle_mark_as_paused(state, data)
      _ -> :keep_state_and_data
    end
  end

  defp handle_update_status(notification, data) do
    ota_operation = notification.payload.data

    additional_actions =
      cond do
        ota_operation_successful?(ota_operation) ->
          [{:next_event, :internal, {:operation_success, ota_operation}}]

        ota_operation_failed?(ota_operation) ->
          [{:next_event, :internal, {:operation_failure_event, ota_operation}}]

        ota_operation_acknowledged?(ota_operation) ->
          # Handle this explicitly so we log a message
          Logger.info("Device #{ota_operation.device_id} acknowledged the update")
          []

        true ->
          # All other updates are no-ops for now
          []
      end

    # We always cancel the retry timeout for every kind of update we see on an OTA Operation.
    # This ensures we don't resend the request even if we accidentally miss the acknowledge.
    # If the timeout does not exist, this is a no-op anyway.
    actions = [
      cancel_retry_timeout(data.tenant_id, ota_operation.id) | additional_actions
    ]

    {:keep_state_and_data, actions}
  end

  defp ota_operation_acknowledged?(ota_operation) do
    ota_operation.status == :acknowledged
  end

  defp ota_operation_successful?(ota_operation) do
    ota_operation.status == :success
  end

  defp ota_operation_failed?(ota_operation) do
    ota_operation.status == :failure
  end

  defp handle_mark_as_paused(state, data) when state in @pauseable_states do
    {:next_state, :wait_for_campaign_paused, data, []}
  end

  defp handle_mark_as_paused(_state, _data) do
    # Ignore pause requests in non-pauseable states (terminal states, already pausing, etc.)
    :keep_state_and_data
  end
end
