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

defmodule Edgehog.Campaigns.CampaignMechanism.DeploymentStart.Executor do
  @moduledoc """
  Executor for lazy deployment campaigns using the generic LazyBatch behavior.

  """
  use Edgehog.Campaigns.Executors.Lazy.LazyBatch

  alias Edgehog.Campaigns.Executors.Lazy.LazyBatch

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
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "deployments:started:" <> _id} = notification,
        _state,
        data
      ) do
    # We subscribed to the `started:deployments:#{id}` event for the deployment
    # we're interested in. Since we received a message, it means that the
    # deployment was started.
    deployment = notification.payload.data

    actions = [
      cancel_retry_timeout(data.tenant_id, deployment.id),
      {:next_event, :internal, {:operation_success, deployment}}
    ]

    {:keep_state_and_data, actions}
  end

  @impl LazyBatch
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "deployments:timeout:" <> _id} = notification,
        _state,
        data
      ) do
    deployment = notification.payload.data

    actions = [
      cancel_retry_timeout(data.tenant_id, deployment.id),
      internal_event({:operation_failure_event, deployment})
    ]

    {:keep_state_and_data, actions}
  end

  @impl LazyBatch
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "campaigns:" <> _id, event: "pause"} = _notification,
        state,
        data
      ) do
    handle_pausing(state, data)
  end

  defp handle_pausing(state, data) when state in @pauseable_states do
    {:next_state, :wait_for_campaign_paused, data, []}
  end

  defp handle_pausing(_state, _data) do
    # Ignore pause requests in non-pauseable states (terminal states, already pausing, etc.)
    :keep_state_and_data
  end
end
