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

defmodule Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Executor do
  @moduledoc """
  Executor for lazy deployment campaigns using the generic LazyBatch behavior.

  Supports multiple operation types (deploy, upgrade, start, stop, delete) through
  campaign-specific configuration.
  """
  use Edgehog.Campaigns.Executors.LazyBatch,
    core: Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core

  alias Edgehog.Campaigns.Executors.LazyBatch
  alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core

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
      :destroy -> handle_destroy(notification, data)
      _ -> :keep_state_and_data
    end
  end

  def handle_info(_message, _state, _data) do
    # Ignore any other messages
    :keep_state_and_data
  end

  defp handle_update(notification, data) do
    case notification.payload.action.name do
      :maybe_run_ready_actions -> handle_maybe_run_ready_actions(notification, data)
      :mark_as_timed_out -> handle_mark_as_timed_out(notification, data)
      _ -> :keep_state_and_data
    end
  end

  defp handle_maybe_run_ready_actions(notification, data) do
    case Map.get(notification.payload.metadata || %{}, :custom_event) do
      :deployment_ready ->
        handle_ready(notification.payload.data, data)

      _ ->
        :keep_state_and_data
    end
  end

  def handle_ready(deployment, data) do
    case {data.campaign_data.operation_type, deployment.state} do
      {:upgrade, :stopped} ->
        # This part of code handles retries for upgrade operations.
        # In Core.retry_target_operation/2, the :send_deployment action is triggered,
        # but upgrades require both deployment and start actions.
        # Therefore, we explicitly trigger the :start operation here if a retry occurred.
        target =
          Core.get_target_for_operation!(
            data.tenant_id,
            data.campaign_id,
            deployment.device_id
          )

        if target.retry_count > 0 do
          Core.retry_target_operation(target, :start)
        end

        # When an upgrade is triggered, the new release deployment must be both deployed and started.
        # We avoid triggering the :deployment_success event while the deployment is only in the
        # :stopped (deployed) state — it should trigger only once the deployment transitions to :started.
        :keep_state_and_data

      _ ->
        # We always cancel the retry timeout for every kind of update we see on an Deployment.
        # This ensures we don't resend the request even if we accidentally miss the acknowledge.
        # If the timeout does not exist, this is a no-op anyway.

        actions = [
          cancel_retry_timeout(data.tenant_id, deployment.id),
          internal_event({:operation_success, deployment})
        ]

        {:keep_state_and_data, actions}
    end
  end

  defp handle_mark_as_timed_out(notification, data) do
    # We always cancel the retry timeout for every kind of update we see on an Deployment.
    # This ensures we don't resend the request even if we accidentally miss the acknowledge.
    # If the timeout does not exist, this is a no-op anyway.
    deployment = notification.payload.data

    actions = [
      cancel_retry_timeout(data.tenant_id, deployment.id),
      internal_event({:operation_failure_event, deployment})
    ]

    {:keep_state_and_data, actions}
  end

  defp handle_destroy(notification, data) do
    case notification.payload.action.name do
      :destroy_and_gc -> handle_destroy_and_gc(notification, data)
      _ -> :keep_state_and_data
    end
  end

  defp handle_destroy_and_gc(notification, data) do
    # We always cancel the retry timeout for every kind of update we see on an Deployment.
    # This ensures we don't resend the request even if we accidentally miss the acknowledge.
    # If the timeout does not exist, this is a no-op anyway.
    deployment = notification.payload.data

    actions = [
      cancel_retry_timeout(data.tenant_id, deployment.id),
      internal_event({:operation_success, deployment})
    ]

    {:keep_state_and_data, actions}
  end
end
