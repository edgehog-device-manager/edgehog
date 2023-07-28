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

defmodule Edgehog.UpdateCampaigns.PushRollout.Executor do
  # We use handle_event_function to allow for arbitrary terms in state, which is useful for states
  # like {:rollout_target, target}
  use GenStateMachine, restart: :transient, callback_mode: [:handle_event_function, :state_enter]

  require Logger

  alias __MODULE__, as: Data
  alias Edgehog.Repo
  alias Edgehog.UpdateCampaigns.Target
  alias Edgehog.UpdateCampaigns.PushRollout.Core

  defstruct [
    :available_slots,
    :base_image,
    :failed_count,
    :in_progress_count,
    :rollout_mechanism,
    :target_count,
    :update_campaign_id
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
    update_campaign_id = Keyword.fetch!(opts, :update_campaign_id)

    # Make sure the process-local tenant is the right one
    Repo.put_tenant_id(tenant_id)

    if opts[:wait_for_start_execution] do
      # Use this to manually start the executor in tests
      {:ok, :wait_for_start_execution, update_campaign_id}
    else
      {:ok, :initialization, update_campaign_id, internal_event(:init_data)}
    end
  end

  # State: :wait_for_start_execution

  @impl GenStateMachine
  def handle_event(:enter, _old_state, :wait_for_start_execution, _update_campaign_id) do
    :keep_state_and_data
  end

  def handle_event(:info, :start_execution, :wait_for_start_execution, update_campaign_id) do
    {:next_state, :initialization, update_campaign_id, internal_event(:init_data)}
  end

  # State: :initialization

  def handle_event(:enter, _old_state, :initialization, update_campaign_id) do
    Logger.info("Update Campaign #{update_campaign_id}: entering the :initialization state")

    :keep_state_and_data
  end

  def handle_event(:internal, :init_data, :initialization, update_campaign_id) do
    # TODO: when we expose the possibility of updating the UpdateCampaign, specifically the rollout,
    # we should publish changes to it via PubSub, subscribing to them here, since we will allow
    # increasing max_in_progress_updates during the campaign execution, which will affect
    # available_slots.
    update_campaign = Core.get_update_campaign!(update_campaign_id)
    base_image = Core.get_update_campaign_base_image!(update_campaign_id)
    target_count = Core.get_target_count(update_campaign_id)
    rollout_mechanism = update_campaign.rollout_mechanism

    data = %Data{
      base_image: base_image,
      rollout_mechanism: rollout_mechanism,
      target_count: target_count,
      update_campaign_id: update_campaign_id
    }

    case update_campaign.status do
      :idle ->
        # Fresh campaign, mark it as in_progress and start it
        _ = Core.mark_update_campaign_as_in_progress!(update_campaign)
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
      rollout_mechanism: rollout_mechanism,
      update_campaign_id: update_campaign_id
    } = data

    # TODO: query Astarte to verify that the cached status is consistent with our local status
    # (possibly spawning a separate task that queries Astarte and updates OTA Operations)
    failed_count = Core.get_failed_target_count(update_campaign_id)
    in_progress_count = Core.get_in_progress_target_count(update_campaign_id)
    available_slots = Core.available_update_slots(rollout_mechanism, in_progress_count)

    new_data = %{
      data
      | failed_count: failed_count,
        in_progress_count: in_progress_count,
        available_slots: available_slots
    }

    # Setup a timer for each pending OTA Operation
    timeout_actions =
      Core.list_targets_with_pending_ota_operation(update_campaign_id)
      |> Enum.map(&setup_retry_timeout(&1, rollout_mechanism))

    # Fetch the next target
    actions = [internal_event(:fetch_next_target) | timeout_actions]

    # Start the rollout
    {:next_state, :rollout, new_data, actions}
  end

  def handle_event(:internal, :start_campaign, :initialization, data) do
    available_slots = Core.available_update_slots(data.rollout_mechanism, 0)

    new_data = %{
      data
      | failed_count: 0,
        in_progress_count: 0,
        available_slots: available_slots
    }

    # Start the rollout, fetching the next target
    {:next_state, :rollout, new_data, internal_event(:fetch_next_target)}
  end

  # State: :rollout

  def handle_event(:enter, _old_state, :rollout, data) do
    Logger.info("Update Campaign #{data.update_campaign_id}: entering the :rollout state")
    :keep_state_and_data
  end

  def handle_event(:internal, :fetch_next_target, :rollout, data) do
    case Core.fetch_next_updatable_target(data.update_campaign_id) do
      {:ok, target} ->
        # Do we have an available slot?
        if slot_available?(data) do
          {:keep_state_and_data, internal_event({:rollout_target, target})}
        else
          # Wait for a slot to be available
          {:next_state, :wait_for_available_slot, data}
        end

      {:error, :no_updatable_targets} ->
        # Are we finished?
        cond do
          # There are still some targets but none of them are online, wait for them
          Core.has_idle_targets?(data.update_campaign_id) ->
            {:next_state, :wait_for_target, data}

          # We don't have any target left to be deployed, but we have to wait for in progress
          # OTA Operations to be finished
          targets_in_progress?(data) ->
            {:next_state, :wait_for_campaign_completion, data}

          # We're finished
          true ->
            {:next_state, :campaign_success, data}
        end
    end
  end

  def handle_event(:internal, {:rollout_target, target}, :rollout, data) do
    # We occupy a slot since we're rolling out an update
    new_data = occupy_slot(data)

    case start_rollout(target, new_data.base_image, new_data.rollout_mechanism) do
      {:ok, :already_at_target_version} ->
        {:keep_state, new_data, internal_event({:already_updated, target})}

      {:ok, %Target{} = target} ->
        {:keep_state, new_data, internal_event({:rolled_out, target})}

      {:error, reason} ->
        if Core.temporary_error?(reason) do
          {:keep_state, new_data, internal_event({:rollout_temporary_error, target, reason})}
        else
          {:keep_state, new_data, internal_event({:rollout_failure, target, reason})}
        end
    end
  end

  def handle_event(:internal, {:already_updated, target}, :rollout, data) do
    # The target already has the same version as the target base_image, we consider this
    # a success.
    Logger.info("Device #{target.device.device_id} was already updated.")
    _ = Core.mark_target_as_successful!(target)

    # We free up the slot since the target is considered completed
    new_data = free_up_slot(data)

    # We stay in this state and fetch the next target
    {:keep_state, new_data, internal_event(:fetch_next_target)}
  end

  def handle_event(:internal, {:rolled_out, target}, :rollout, data) do
    # Receive updates for the OTA Operation so we can track it
    Core.subscribe_to_ota_operation_updates!(target.ota_operation_id)

    actions = [
      # Fetch the next target
      internal_event(:fetch_next_target),
      # Setup a timeout for the OTA Operation retry
      setup_retry_timeout(target, data.rollout_mechanism)
    ]

    {:keep_state_and_data, actions}
  end

  def handle_event(:internal, {:rollout_temporary_error, target, reason}, :rollout, data) do
    Core.error_message(reason, target.device.device_id)
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

  def handle_event(:internal, {:rollout_failure, target, reason}, :rollout, data) do
    Core.error_message(reason, target.device.device_id)
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
    Logger.info(
      "Update Campaign #{data.update_campaign_id}: entering the :wait_for_available_slot state"
    )

    # Just wait here, we will exit this state when we receive some updates on successful/failed
    # OTA Operations
    :keep_state_and_data
  end

  # State: :wait_for_target

  def handle_event(:enter, _old_state, :wait_for_target, data) do
    Logger.info("Update Campaign #{data.update_campaign_id}: entering the :wait_for_target state")

    # TODO: start tracking offline targets so we can rollout them as soon as they come back online.
    # For now we just setup a state timeout and try to fetch the next target after 15 seconds
    action = {:state_timeout, 15_000, :check_target}
    {:keep_state_and_data, action}
  end

  def handle_event(:state_timeout, :check_target, :wait_for_target, data) do
    # Check to see if we have any new targets available
    {:next_state, :rollout, data, internal_event(:fetch_next_target)}
  end

  # State: :wait_for_campaign_completion

  def handle_event(:enter, _old_state, :wait_for_campaign_completion, data) do
    Logger.info(
      "Update Campaign #{data.update_campaign_id}: entering the :wait_for_campaign_completion state"
    )

    :keep_state_and_data
  end

  # State: :campaign_failure

  def handle_event(:enter, _old_state, :campaign_failure, data) do
    Logger.notice("Update campaign #{data.update_campaign_id} terminated with a failure")

    _ =
      Core.get_update_campaign!(data.update_campaign_id)
      |> Core.mark_update_campaign_as_failed!()

    {:stop, :normal}
  end

  # State: :campaign_success

  def handle_event(:enter, _old_state, :campaign_success, data) do
    Logger.info("Update campaign #{data.update_campaign_id} terminated with a success")

    _ =
      Core.get_update_campaign!(data.update_campaign_id)
      |> Core.mark_update_campaign_as_successful!()

    {:stop, :normal}
  end

  # Common event handling

  # Note that external (e.g. :info) and timeout events are always handled after the internal
  # events enqueued with the :next_event action. This means that we can be sure an :info event
  # or a timeout won't be handled, e.g., between a rollout and the handling of its error

  def handle_event(:info, {:ota_operation_updated, ota_operation}, _state, _data) do
    # Event generated from PubSub when an OTAOperation is updated
    additional_actions =
      cond do
        Core.ota_operation_successful?(ota_operation) ->
          [internal_event({:ota_operation_success, ota_operation})]

        Core.ota_operation_failed?(ota_operation) ->
          [internal_event({:ota_operation_failure, ota_operation})]

        Core.ota_operation_acknowledged?(ota_operation) ->
          # Handle this explicitly so we log a message
          Logger.info("Device #{ota_operation.device.device_id} acknowledged the update")
          []

        true ->
          # All other updates are no-ops for now
          []
      end

    # We always cancel the retry timeout for every kind of update we see on an OTA Operation.
    # This ensures we don't resend the request even if we accidentally miss the acknowledge.
    # If the timeout does not exist, this is a no-op anyway.
    actions = [cancel_retry_timeout(ota_operation.id) | additional_actions]

    {:keep_state_and_data, actions}
  end

  def handle_event(:internal, {:ota_operation_success, ota_operation}, _state, data) do
    Logger.info("Device #{ota_operation.device.device_id} updated successfully")

    _ =
      Core.get_target_for_ota_operation!(ota_operation.id)
      |> Core.mark_target_as_successful!()

    # The OTA Operation has finished, so we free up a slot
    new_data = free_up_slot(data)

    {:keep_state, new_data, internal_event(:ota_operation_completion)}
  end

  def handle_event(:internal, {:ota_operation_failure, ota_operation}, _state, data) do
    Logger.notice(
      "Device #{ota_operation.device.device_id} failed to update: #{ota_operation.status_code}"
    )

    _ =
      Core.get_target_for_ota_operation!(ota_operation.id)
      |> Core.mark_target_as_failed!()

    # Since the target was occupying a slot and we're marking it as failed, free up the slot
    new_data =
      data
      |> add_failure()
      |> free_up_slot()

    if failure_threshold_exceeded?(new_data) do
      {:next_state, :campaign_failure, new_data}
    else
      {:keep_state, new_data, internal_event(:ota_operation_completion)}
    end
  end

  def handle_event(:internal, :ota_operation_completion, state, data) do
    cond do
      state == :wait_for_available_slot ->
        # If we were waiting for a free slot, we fetch the next target
        {:next_state, :rollout, data, internal_event(:fetch_next_target)}

      state == :wait_for_campaign_completion and not targets_in_progress?(data) ->
        # We finished updating everything, go to the final state for the finishing touches
        {:next_state, :campaign_success, data}

      true ->
        # Otherwise, we keep doing what we were doing
        :keep_state_and_data
    end
  end

  def handle_event({:timeout, {:retry, _ota_operation_id}}, target_id, _state, data) do
    target = Core.get_target!(target_id)

    if Core.can_retry?(target, data.rollout_mechanism) do
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

    case Core.retry_target_update(target, data.base_image) do
      :ok ->
        # Setup a timeout for the OTA Operation retry
        action = setup_retry_timeout(target, data.rollout_mechanism)

        {:keep_state_and_data, action}

      {:error, reason} ->
        Core.error_message(reason, target.device.device_id)
        |> Logger.notice()

        # We don't check if the error is temporary or not, since by definition it shouldn't be
        # because we already have a successful pending OTA request if we're here.
        # If we failed during a retry, we just schedule another timeout after the retry timeout
        # period, and we'll do another retry (in this case we're counting them towards the retry
        # count since the OTA Operation, differently from the case where we fail during the initial
        # rollout)
        # TODO: evaluate if this is the desired behaviour
        action = setup_retry_timeout(target, data.rollout_mechanism)

        {:keep_state_and_data, action}
    end
  end

  def handle_event(:internal, {:retry_threshold_exceeded, target}, _state, _data) do
    Logger.notice("Device #{target.device.device_id} update failed: no more retries left")

    # Just mark the OTA Operation as failed with request_timeout. The associated target will
    # be marked as failed when it receives the :ota_operation_updated message from the PubSub
    _ = Core.mark_ota_operation_as_timed_out!(target.ota_operation_id)

    :keep_state_and_data
  end

  # Internal helpers

  defp start_rollout(target, base_image, rollout_mechanism) do
    with {:ok, target_current_version} <- Core.fetch_target_current_version(target) do
      if Core.needs_update?(target_current_version, base_image) do
        verify_compatibility_and_update(
          target,
          target_current_version,
          base_image,
          rollout_mechanism
        )
      else
        {:ok, :already_at_target_version}
      end
    end
  end

  defp verify_compatibility_and_update(
         target,
         target_current_version,
         base_image,
         rollout_mechanism
       ) do
    with :ok <- Core.verify_compatibility(target_current_version, base_image, rollout_mechanism) do
      target = Core.update_target_latest_attempt!(target, DateTime.utc_now())
      Core.start_target_update(target, base_image)
    end
  end

  # Action helpers

  defp setup_retry_timeout(target, rollout_mechanism) do
    # Create a generic timeout identified by the OTA Operation ID so we can cancel it if the
    # OTA Operation gets updated with an ack.
    # Note that this works correctly even if the timeout is already expired (e.g. when resuming
    # a campaign) since Core.pending_ota_request_timeout_ms will return 0 in that case, and
    # setting up a 0 timer will enqueue the timer action event immediately.
    timeout_ms = Core.pending_ota_request_timeout_ms(target, rollout_mechanism)
    {{:timeout, {:retry, target.ota_operation_id}}, timeout_ms, target.id}
  end

  defp cancel_retry_timeout(ota_operation_id) do
    # Cancel the pending retry timer
    {{:timeout, {:retry, ota_operation_id}}, :cancel}
  end

  defp internal_event(payload) do
    {:next_event, :internal, payload}
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
      rollout_mechanism: rollout_mechanism,
      target_count: target_count
    } = data

    Core.failure_threshold_exceeded?(target_count, failed_count, rollout_mechanism)
  end

  defp slot_available?(data) do
    data.available_slots > 0
  end

  defp targets_in_progress?(data) do
    data.in_progress_count > 0
  end
end
