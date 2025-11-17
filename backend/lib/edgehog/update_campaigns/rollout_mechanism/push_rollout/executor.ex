#
# This file is part of Edgehog.
#
# Copyright 2023-2025 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout.Executor do
  @moduledoc """
  Executor for OTA update campaigns using the generic LazyBatch executor.
  """

  use Edgehog.Campaigns.Executors.LazyBatch,
    core: Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout.Core

  alias Edgehog.Campaigns.Executors.LazyBatch
  alias Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout.Core

  require Logger

  @impl LazyBatch
  def handle_info(:start_execution, :wait_for_start_execution, data) do
    {:next_state, :initialization, data, internal_event(:init_data)}
  end

  # Common event handling

  # Note that external (e.g. :info) and timeout events are always handled after the internal
  # events enqueued with the :next_event action. This means that we can be sure an :info event
  # or a timeout won't be handled, e.g., between a rollout and the handling of its error

  def handle_info(%Phoenix.Socket.Broadcast{} = notification, _state, data) do
    case notification.payload.action.type do
      :update -> handle_update(notification, data)
      _ -> :keep_state_and_data
    end
  end

  def handle_info(_message, _state, _data) do
    # Ignore any other messages
    :keep_state_and_data
  end

  defp handle_update(notification, data) do
    ota_operation = notification.payload.data

    additional_actions =
      cond do
        Core.ota_operation_successful?(ota_operation) ->
          [internal_event({:operation_success, ota_operation})]

        Core.ota_operation_failed?(ota_operation) ->
          [internal_event({:operation_failure_event, ota_operation})]

        Core.ota_operation_acknowledged?(ota_operation) ->
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
    actions = [cancel_retry_timeout(data.tenant_id, ota_operation.id) | additional_actions]

    {:keep_state_and_data, actions}
  end
end
