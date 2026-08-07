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

defmodule Edgehog.Campaigns.CampaignMechanism.DeploymentDeploy.Executor do
  @moduledoc """
  Executor for lazy deployment campaigns using the generic LazyBatch behavior.

  """
  use Edgehog.Campaigns.Executors.Lazy.LazyBatch

  alias Edgehog.Campaigns.Executors.Lazy.LazyBatch

  @impl LazyBatch
  def handle_info(:start_execution, :wait_for_start_execution, data) do
    {:next_state, :initialization, data, internal_event(:init_data)}
  end

  # Note that external (e.g. :info) and timeout events are always handled after the internal
  # events enqueued with the :next_event action. This means that we can be sure an :info event
  # or a timeout won't be handled, e.g., between a rollout and the handling of its error
  # Valid states from which pausing is allowed
  @pauseable_states [
    :execution,
    :wait_for_available_slot,
    :wait_for_target,
    :wait_for_campaign_completion
  ]

  # Common event handling

  @impl LazyBatch
  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "deployments:timeout:" <> _} = notification,
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

  # NOTE: the other topic we subscribed is the readiness topic for the
  # deployment resource. Since the topic depends on the resource we prefer not
  # to hard code it here. Beware of messages
  @impl LazyBatch
  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: deployment}, _state, data) do
    case event do
      :ready -> handle_ready(deployment, data)
      :failure -> handle_failure(deployment, data)
    end
  end

  defp handle_pausing(state, data) when state in @pauseable_states do
    {:next_state, :wait_for_campaign_paused, data, []}
  end

  defp handle_pausing(_state, _data) do
    # Ignore pause requests in non-pauseable states (terminal states, already pausing, etc.)
    :keep_state_and_data
  end

  defp handle_ready(deployment, data) do
    # We always cancel the retry timeout for every kind of update we see on a Deployment.
    # This ensures we don't resend the request even if we accidentally miss the acknowledge.
    # If the timeout does not exist, this is a no-op anyway.

    actions = [
      cancel_retry_timeout(data.tenant_id, deployment.id),
      {:next_event, :internal, {:operation_success, deployment}}
    ]

    {:keep_state_and_data, actions}
  end

  defp handle_failure(deployment, data) do
    # We always cancel the retry timeout for every kind of update we see on an Deployment.
    # This ensures we don't resend the request even if we accidentally miss the acknowledge.
    # If the timeout does not exist, this is a no-op anyway.

    actions =
      [
        cancel_retry_timeout(data.tenant_id, deployment.id),
        internal_event({:operation_failure_event, deployment})
      ]

    {:keep_state_and_data, actions}
  end
end
