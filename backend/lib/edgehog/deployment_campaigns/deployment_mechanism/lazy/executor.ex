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
  Executor for lazy deployment campaigns with support for multiple operation types.

  This module implements a GenStateMachine that manages the execution of deployment campaigns.
  It supports different operation types (deploy, upgrade, start, stop, delete) through a
  modular architecture that allows easy extension for future operations.
  """
  use GenStateMachine, restart: :transient, callback_mode: [:handle_event_function, :state_enter]

  alias __MODULE__, as: State
  alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core
  alias Edgehog.DeploymentCampaigns.DeploymentTarget

  require Logger

  defstruct [
    :operation_type,
    :available_slots,
    :release,
    :target_release,
    :containers,
    :networks,
    :volumes,
    :images,
    :failed_count,
    :in_progress_count,
    :deployment_mechanism,
    :target_count,
    :deployment_campaign_id,
    :tenant_id
  ]

  # Public API

  def start_link(args) do
    name = args[:name] || __MODULE__

    GenStateMachine.start_link(__MODULE__, args, name: name)
  end

  # Callbacks

  @impl GenStateMachine
  def init(opts) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    deployment_campaign_id = Keyword.fetch!(opts, :campaign_id)

    data = %State{
      deployment_campaign_id: deployment_campaign_id,
      tenant_id: tenant_id
    }

    if opts[:wait_for_start_execution] do
      # Use this to manually start the executor in tests
      {:ok, :wait_for_start_execution, data}
    else
      {:ok, :initialization, data, internal_event(:init_data)}
    end
  end

  # State: :wait_for_start_execution

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :wait_for_start_execution, _data) do
    :keep_state_and_data
  end

  def handle_event(:info, :start_execution, :wait_for_start_execution, data) do
    {:next_state, :initialization, data, internal_event(:init_data)}
  end

  # State: :initialization

  def handle_event(:enter, _old_state, :initialization, data) do
    %State{deployment_campaign_id: deployment_campaign_id} = data

    Logger.info("Deployment Campaign #{deployment_campaign_id}: entering the :initialization state")

    :keep_state_and_data
  end

  def handle_event(:internal, :init_data, :initialization, data) do
    %State{
      deployment_campaign_id: deployment_campaign_id,
      tenant_id: tenant_id
    } = data

    # TODO: when we expose the possibility of updating the DeploymentCampaign,
    # specifically the rollout, we should publish changes to it via PubSub,
    # subscribing to them here, since we will allow increasing
    # max_in_progress_updates during the campaign execution, which will affect
    # available_slots.
    deployment_campaign =
      tenant_id
      |> Core.get_deployment_campaign!(deployment_campaign_id)
      |> Ash.load!(
        [target_release: [], release: [containers: [:networks, :volumes, :image]]],
        tenant: tenant_id
      )
      |> Ash.load!(:total_target_count)

    operation_type = deployment_campaign.operation_type

    release = deployment_campaign.release
    target_release = deployment_campaign.target_release

    containers = Core.get_release_containers(tenant_id, release)

    volumes =
      containers
      |> Enum.flat_map(&Core.get_container_volumes(tenant_id, &1))
      |> Enum.uniq_by(& &1.id)

    networks =
      containers
      |> Enum.flat_map(&Core.get_container_networks(tenant_id, &1))
      |> Enum.uniq_by(& &1.id)

    images =
      containers
      |> Enum.map(&Core.get_container_image(tenant_id, &1))
      |> Enum.uniq_by(& &1.id)

    target_count = Core.get_target_count(tenant_id, deployment_campaign)
    deployment_mechanism = deployment_campaign.deployment_mechanism.value

    data = %State{
      operation_type: operation_type,
      release: release,
      target_release: target_release,
      volumes: volumes,
      networks: networks,
      images: images,
      deployment_mechanism: deployment_mechanism,
      target_count: target_count,
      deployment_campaign_id: deployment_campaign_id,
      tenant_id: tenant_id
    }

    case deployment_campaign.status do
      :idle ->
        # Fresh campaign, mark it as in_progress and start it
        _ = Core.mark_deployment_campaign_in_progress!(deployment_campaign)
        {:keep_state, data, internal_event(:start_campaign)}

      :in_progress ->
        # Campaign already in progress, resume it
        {:keep_state, data, internal_event(:resume_campaign)}

      :finished ->
        # Nothing to do here
        {:stop, :normal}
    end
  end

  def handle_event(:internal, :resume_campaign, :initialization, data) do
    %{
      deployment_mechanism: deployment_mechanism,
      deployment_campaign_id: deployment_campaign_id,
      tenant_id: tenant_id
    } = data

    # TODO: query Astarte to verify that the cached status is consistent with our local status
    # (possibly spawning a separate task that queries Astarte and updates deployments)
    failed_count = Core.get_failed_target_count(tenant_id, deployment_campaign_id)
    in_progress_count = Core.get_in_progress_target_count(tenant_id, deployment_campaign_id)
    available_slots = Core.available_slots(deployment_mechanism, in_progress_count)

    new_data = %{
      data
      | failed_count: failed_count,
        in_progress_count: in_progress_count,
        available_slots: available_slots
    }

    timeout_actions =
      tenant_id
      |> Core.list_in_progress_targets(deployment_campaign_id)
      |> Enum.map(fn in_progress_target ->
        # Side effect: receive updates for the deployment so we can track it
        Core.subscribe_to_deployment_updates!(in_progress_target.deployment_id)

        # Return the retry timeout action for the pending target
        setup_retry_timeout(tenant_id, in_progress_target, deployment_mechanism)
      end)

    # Fetch the next target
    actions = [internal_event(:fetch_next_target) | timeout_actions]

    # Start the rollout
    {:next_state, :deployment, new_data, actions}
  end

  def handle_event(:internal, :start_campaign, :initialization, data) do
    available_slots = Core.available_slots(data.deployment_mechanism, 0)

    new_data = %{
      data
      | failed_count: 0,
        in_progress_count: 0,
        available_slots: available_slots
    }

    # Start the rollout, fetching the next target
    {:next_state, :deployment, new_data, internal_event(:fetch_next_target)}
  end

  # State: :deployment

  def handle_event(:enter, _old_state, :deployment, data) do
    Logger.info("Deployment Campaign #{data.deployment_campaign_id}: entering the :deployment state")

    :keep_state_and_data
  end

  def handle_event(:internal, :fetch_next_target, :deployment, data) do
    target_response =
      if data.operation_type == :deploy do
        Core.fetch_next_valid_target(data.tenant_id, data.deployment_campaign_id)
      else
        Core.fetch_next_valid_target_with_application_deployed(
          data.tenant_id,
          data.deployment_campaign_id,
          data.release.application_id
        )
      end

    case target_response do
      {:ok, target} ->
        # Do we have an available slot?
        if slot_available?(data) do
          {:keep_state_and_data, internal_event({:operation_target, target})}
        else
          # Wait for a slot to be available
          {:next_state, :wait_for_available_slot, data}
        end

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} ->
        # Are we finished?
        cond do
          # There are still some targets but none of them are online, wait for them
          Core.has_idle_targets?(data.tenant_id, data.deployment_campaign_id) ->
            {:next_state, :wait_for_target, data}

          # We don't have any target left to be deployed, but we have to wait for in progress
          # deployments to be finished
          targets_in_progress?(data) ->
            {:next_state, :wait_for_campaign_completion, data}

          # We're finished
          true ->
            {:next_state, :campaign_success, data}
        end
    end
  end

  def handle_event(:internal, {:operation_target, target}, :deployment, data) do
    # We occupy a slot since we're rolling out a deployment
    new_data = occupy_slot(data)

    case Core.do_operation(
           target,
           new_data.release,
           new_data.target_release,
           new_data.deployment_mechanism,
           new_data.operation_type
         ) do
      {:ok, :already_in_desired_state} ->
        {:keep_state, new_data, internal_event({:already_in_desired_state, target})}

      {:ok, %DeploymentTarget{} = target} ->
        {:keep_state, new_data, internal_event({:deployed, target})}

      {:error, reason} ->
        if Core.temporary_error?(reason) do
          {:keep_state, new_data, internal_event({:deployment_temporary_error, target, reason})}
        else
          {:keep_state, new_data, internal_event({:deployment_failure, target, reason})}
        end
    end
  end

  def handle_event(:internal, {:already_in_desired_state, target}, :deployment, data) do
    # The target already has the operation completed, just log and mark it as successful
    log_operation_already_completed(data.operation_type, target.device_id)
    _ = Core.mark_target_as_successful!(target)

    # We free up the slot since the target is considered completed
    new_data = free_up_slot(data)

    # We stay in this state and fetch the next target
    {:keep_state, new_data, internal_event(:fetch_next_target)}
  end

  def handle_event(:internal, {:deployed, target}, :deployment, data) do
    # Receive updates for the Deployment so we can track it
    Core.subscribe_to_deployment_updates!(target.deployment_id)

    actions = [
      # Fetch the next target
      internal_event(:fetch_next_target),
      # Setup a timeout for the Deployment retry
      setup_retry_timeout(data.tenant_id, target, data.deployment_mechanism)
    ]

    {:keep_state_and_data, actions}
  end

  def handle_event(:internal, {:deployment_temporary_error, target, reason}, :deployment, data) do
    reason
    |> Core.error_message(target.device_id)
    |> Logger.notice()

    # Since this is a temporary error, and we failed during the initial rollout, for now we do
    # nothing and just try the next target, which will be a different one since we're ordering
    # by latest attempt. This doesn't count towards the retries for the target.
    # TODO: evaluate if this is the desired behaviour

    # We free up the slot since the target here remains in an idle state and it's not pending
    new_data = free_up_slot(data)

    # We stay in this state and fetch the next target
    {:keep_state, new_data, internal_event(:fetch_next_target)}
  end

  def handle_event(:internal, {:deployment_failure, target, reason}, :deployment, data) do
    reason
    |> Core.error_message(target.device_id)
    |> Logger.notice()

    # This is a permanent failure, so we mark the target as failed
    _ = Core.mark_target_as_failed!(target)

    # We also increase failure and free up the slot since the target is in a final failure state

    new_data =
      data
      |> add_failure()
      |> free_up_slot()

    if failure_threshold_exceeded?(new_data) do
      {:next_state, :campaign_failure, new_data}
    else
      # We stay in this state and fetch the next target
      {:keep_state, new_data, internal_event(:fetch_next_target)}
    end
  end

  # State: :wait_for_available_slot

  def handle_event(:enter, _old_state, :wait_for_available_slot, data) do
    Logger.info("Deployment Campaign #{data.deployment_campaign_id}: entering the :wait_for_available_slot state")

    # Just wait here, we will exit this state when we receive some updates on successful/failed
    # Deployments
    :keep_state_and_data
  end

  # State: :wait_for_target

  def handle_event(:enter, _old_state, :wait_for_target, data) do
    Logger.info("Deployment Campaign #{data.deployment_campaign_id}: entering the :wait_for_target state")

    # TODO: start tracking offline targets so we can rollout them as soon as they come back online.
    # For now we just setup a state timeout and try to fetch the next target after 15 seconds
    action = {:state_timeout, 15_000, :check_target}
    {:keep_state_and_data, action}
  end

  def handle_event(:state_timeout, :check_target, :wait_for_target, data) do
    # Check to see if we have any new targets available
    {:next_state, :deployment, data, internal_event(:fetch_next_target)}
  end

  # State: :wait_for_campaign_completion

  def handle_event(:enter, _old_state, :wait_for_campaign_completion, data) do
    Logger.info("Deployment Campaign #{data.deployment_campaign_id}: entering the :wait_for_campaign_completion state")

    :keep_state_and_data
  end

  # State: :campaign_failure

  def handle_event(:enter, _old_state, :campaign_failure, data) do
    Logger.notice("Deployment campaign #{data.deployment_campaign_id} terminated with a failure")

    _ =
      data.tenant_id
      |> Core.get_deployment_campaign!(data.deployment_campaign_id)
      |> Core.mark_deployment_campaign_as_failed!()

    if targets_in_progress?(data) do
      # Here we don't terminate immediately, otherwise we would lose all the updates for the targets
      # that are currently in progress. If all the remaining targets reach a final state, we will
      # terminate while handling the relative :deployment_completion internal event. Otherwise,
      # the executor will terminate after the grace period.
      termination_grace_period = :timer.hours(1)
      action = {:state_timeout, termination_grace_period, :terminate_executor}
      {:keep_state_and_data, action}
    else
      # If we don't have any other in progress updates, we just terminate right away
      terminate_executor(data.deployment_campaign_id)
    end
  end

  def handle_event(:state_timeout, :terminate_executor, :campaign_failure, data) do
    # Grace period is over, terminate the executor
    terminate_executor(data.deployment_campaign_id)
  end

  # State: :campaign_success

  def handle_event(:enter, _old_state, :campaign_success, data) do
    Logger.info("Deployment campaign #{data.deployment_campaign_id} terminated with a success")

    _ =
      data.tenant_id
      |> Core.get_deployment_campaign!(data.deployment_campaign_id)
      |> Core.mark_deployment_campaign_as_successful!()

    terminate_executor(data.deployment_campaign_id)
  end

  # Common event handling

  # Note that external (e.g. :info) and timeout events are always handled after the internal
  # events enqueued with the :next_event action. This means that we can be sure an :info event
  # or a timeout won't be handled, e.g., between a rollout and the handling of its error

  def handle_event(:info, %{payload: {:deployment_ready, deployment}}, _state, data) do
    case {data.operation_type, deployment.state} do
      {:upgrade, :stopped} ->
        # This part of code handles retries for upgrade operations.
        # In Core.retry_target_operation/2, the :send_deployment action is triggered,
        # but upgrades require both deployment and start actions.
        # Therefore, we explicitly trigger the :start operation here if a retry occurred.
        target =
          Core.get_target_for_deployment_by_device!(
            data.tenant_id,
            data.deployment_campaign_id,
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
          internal_event({:deployment_success, deployment})
        ]

        Core.unsubscribe_to_deployment_updates!(deployment.id)

        {:keep_state_and_data, actions}
    end
  end

  # Ignore deployment_updated events, when everything will be ready the resource
  # will emit a `:deployment_ready` event
  def handle_event(:info, %{payload: {:deployment_updated, _deployment}}, _state, _data) do
    :keep_state_and_data
  end

  def handle_event(:info, %{payload: {:deployment_deleted, deployment}}, _state, data) do
    # We always cancel the retry timeout for every kind of update we see on an Deployment.
    # This ensures we don't resend the request even if we accidentally miss the acknowledge.
    # If the timeout does not exist, this is a no-op anyway.
    actions = [
      cancel_retry_timeout(data.tenant_id, deployment.id),
      internal_event({:deployment_success, deployment})
    ]

    Core.unsubscribe_to_deployment_updates!(deployment.id)

    {:keep_state_and_data, actions}
  end

  def handle_event(:info, %{payload: {:deployment_timeout, deployment}}, _state, data) do
    # We always cancel the retry timeout for every kind of update we see on an Deployment.
    # This ensures we don't resend the request even if we accidentally miss the acknowledge.
    # If the timeout does not exist, this is a no-op anyway.
    actions = [
      cancel_retry_timeout(data.tenant_id, deployment.id),
      internal_event({:deployment_failure, deployment})
    ]

    Core.unsubscribe_to_deployment_updates!(deployment.id)

    {:keep_state_and_data, actions}
  end

  def handle_event(:internal, {:deployment_success, deployment}, _state, data) do
    log_operation_success(data.operation_type, deployment.device_id)

    _ =
      data.tenant_id
      |> Core.get_target_for_deployment_by_device!(
        data.deployment_campaign_id,
        deployment.device_id
      )
      |> Core.mark_target_as_successful!()

    # The Deployment has finished, so we free up a slot
    new_data = free_up_slot(data)

    {:keep_state, new_data, internal_event(:deployment_completion)}
  end

  def handle_event(:internal, {:deployment_failure, deployment}, state, data) do
    latest_error_message =
      case Core.get_latest_error_for_deployment!(deployment.tenant_id, deployment.id) do
        %{message: message} -> message
        nil -> "Could not find any error event."
      end

    log_operation_failure(
      data.operation_type,
      deployment.device_id,
      latest_error_message
    )

    _ =
      data.tenant_id
      |> Core.get_target_for_deployment_by_device!(
        data.deployment_campaign_id,
        deployment.device_id
      )
      |> Core.mark_target_as_failed!()

    # Since the target was occupying a slot and we're marking it as failed, free up the slot
    new_data =
      data
      |> add_failure()
      |> free_up_slot()

    if state != :campaign_failure and failure_threshold_exceeded?(new_data) do
      # Enter the :campaign_failure state if it's the first time we exceed the threshold
      {:next_state, :campaign_failure, new_data}
    else
      # Otherwise, we just handle the Deployment completion
      {:keep_state, new_data, internal_event(:deployment_completion)}
    end
  end

  def handle_event(:internal, :deployment_completion, state, data) do
    cond do
      state == :wait_for_available_slot ->
        # If we were waiting for a free slot, we fetch the next target
        {:next_state, :deployment, data, internal_event(:fetch_next_target)}

      state == :wait_for_campaign_completion and not targets_in_progress?(data) ->
        # We finished updating everything, go to the final state for the finishing touches
        {:next_state, :campaign_success, data}

      state == :campaign_failure and not targets_in_progress?(data) ->
        # We received all the updates for the remaining targets, we can terminate
        terminate_executor(data.deployment_campaign_id)

      true ->
        # Otherwise, we keep doing what we were doing
        :keep_state_and_data
    end
  end

  def handle_event({:timeout, {:retry, _deployment_id}}, target_id, _state, data) do
    target = Core.get_target!(data.tenant_id, target_id)

    if Core.can_retry?(target, data.deployment_mechanism) do
      {:keep_state_and_data, internal_event({:retry_target, target})}
    else
      {:keep_state_and_data, internal_event({:retry_threshold_exceeded, target})}
    end
  end

  def handle_event(:internal, {:retry_target, target}, _state, data) do
    # Increase retry count and bump latest attempt
    target =
      target
      |> Core.increase_retry_count!()
      |> Core.update_target_latest_attempt!(DateTime.utc_now())

    case Core.retry_target_operation(target, data.operation_type) do
      :ok ->
        # Setup a timeout for the Deployment retry
        action = setup_retry_timeout(data.tenant_id, target, data.deployment_mechanism)

        {:keep_state_and_data, action}

      {:error, reason} ->
        reason
        |> Core.error_message(target.device_id)
        |> Logger.notice()

        # We don't check if the error is temporary or not, since by definition
        # it shouldn't be because we already have a successful pending
        # Deployment request if we're here. If we failed during a retry, we just
        # schedule another timeout after the retry timeout period, and we'll do
        # another retry (in this case we're counting them towards the retry
        # count since the Deployment, differently from the case where we fail
        # during the initial rollout) TODO: evaluate if this is the desired
        # behaviour
        action = setup_retry_timeout(data.tenant_id, target, data.deployment_mechanism)

        {:keep_state_and_data, action}
    end
  end

  def handle_event(:internal, {:retry_threshold_exceeded, target}, _state, data) do
    Logger.notice("Device #{target.device_id} update failed: no more retries left")

    _ = Core.mark_deployment_as_timed_out!(data.tenant_id, target.deployment_id)

    :keep_state_and_data
  end

  # Action helpers

  defp setup_retry_timeout(tenant_id, target, deployment_mechanism) do
    # Create a generic timeout identified by the Deployment ID so we can cancel
    # it if the Deployment gets updated with an ack. Note that this works
    # correctly even if the timeout is already expired (e.g. when resuming a
    # campaign) since Core.pending_deployment_request_timeout_ms will return 0
    # in that case, and setting up a 0 timer will enqueue the timer action event
    # immediately.
    timeout_ms = Core.pending_deployment_request_timeout_ms(target, deployment_mechanism)
    {{:timeout, {:retry, {tenant_id, target.deployment_id}}}, timeout_ms, target.id}
  end

  defp cancel_retry_timeout(tenant_id, deployment_id) do
    # Cancel the pending retry timer
    {{:timeout, {:retry, {tenant_id, deployment_id}}}, :cancel}
  end

  defp internal_event(payload) do
    {:next_event, :internal, payload}
  end

  defp terminate_executor(deployment_campaign_id) do
    Logger.info("Terminating executor process for Deployment Campaign #{deployment_campaign_id}")
    {:stop, :normal}
  end

  # Data manipulation

  defp occupy_slot(data) do
    %{
      data
      | available_slots: data.available_slots - 1,
        in_progress_count: data.in_progress_count + 1
    }
  end

  defp free_up_slot(data) do
    %{
      data
      | available_slots: data.available_slots + 1,
        in_progress_count: data.in_progress_count - 1
    }
  end

  defp add_failure(data) do
    %{
      data
      | failed_count: data.failed_count + 1
    }
  end

  defp failure_threshold_exceeded?(data) do
    %{
      failed_count: failed_count,
      deployment_mechanism: deployment_mechanism,
      target_count: target_count
    } = data

    Core.failure_threshold_exceeded?(target_count, failed_count, deployment_mechanism)
  end

  defp slot_available?(data) do
    data.available_slots > 0
  end

  defp targets_in_progress?(data) do
    data.in_progress_count > 0
  end

  # Logging helpers

  defp log_operation_already_completed(:deploy, device_id) do
    Logger.info("Device #{device_id} was already deployed.")
  end

  defp log_operation_already_completed(operation_type, device_id) do
    Logger.info("Device #{device_id}: #{operation_type} operation already completed.")
  end

  defp log_operation_success(operation_type, device_id) do
    Logger.info("Device #{device_id} #{operation_type} operation completed successfully")
  end

  defp log_operation_failure(operation_type, device_id, error_message) do
    Logger.notice("Device #{device_id} #{operation_type} operation failed: #{error_message}")
  end
end
