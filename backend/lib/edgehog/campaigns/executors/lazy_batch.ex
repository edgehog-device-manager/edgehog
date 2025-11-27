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

defmodule Edgehog.Campaigns.Executors.LazyBatch do
  @moduledoc """
  Generic lazy batch executor for campaigns using a macro-based approach.
  """

  require Logger

  # Define the data struct here so it can be referenced in typespecs
  defstruct [
    :campaign_id,
    :tenant_id,
    :mechanism,
    :campaign_data,
    :available_slots,
    :failed_count,
    :in_progress_count,
    :target_count,
    :core_module
  ]

  @type t :: %__MODULE__{
          campaign_id: integer(),
          tenant_id: integer(),
          mechanism: term(),
          campaign_data: map(),
          available_slots: non_neg_integer(),
          failed_count: non_neg_integer(),
          in_progress_count: non_neg_integer(),
          target_count: non_neg_integer(),
          core_module: module()
        }

  @doc """
  Callback for handling `:info` messages.

  This callback is invoked when the executor receives a message.
  Implementing modules should pattern match on the message and return
  the same result type as `GenStateMachine.handle_event/4`.
  """
  @callback handle_info(message :: term(), state :: atom(), data :: t()) ::
              :gen_statem.event_handler_result(:state_enter)

  @doc """
  Handles all GenStateMachine events. This function is called by the using module's
  `handle_event/4` callback.
  """
  def handle_event(event_type, event_content, state, data)

  # State: :wait_for_start_execution (for testing)

  def handle_event(:enter, _old_state, :wait_for_start_execution, _data) do
    :keep_state_and_data
  end

  def handle_event(:info, :start_execution, :wait_for_start_execution, data) do
    {:next_state, :initialization, data, internal_event(:init_data)}
  end

  # State: :initialization

  def handle_event(:enter, _old_state, :initialization, data) do
    Logger.info("Campaign #{data.campaign_id}: entering :initialization state")

    :keep_state_and_data
  end

  def handle_event(:internal, :init_data, :initialization, data) do
    %{campaign_id: campaign_id, tenant_id: tenant_id, core_module: core_module} = data

    # TODO: when we expose the possibility of updating the Campaign,
    # specifically the rollout, we should publish changes to it via PubSub,
    # subscribing to them here, since we will allow increasing
    # max_in_progress_updates during the campaign execution, which will affect
    # available_slots.
    campaign = core_module.get_campaign!(tenant_id, campaign_id)
    campaign_status = core_module.get_campaign_status(campaign)

    # Early exit if campaign is already finished
    if campaign_status == :finished do
      {:stop, :normal}
    else
      mechanism = core_module.get_mechanism(campaign)
      target_count = core_module.get_target_count(tenant_id, campaign_id)
      campaign_data = core_module.load_campaign_data(tenant_id, campaign)

      data = %{
        data
        | mechanism: mechanism,
          campaign_data: campaign_data,
          target_count: target_count
      }

      case campaign_status do
        :idle ->
          # Fresh campaign, mark it as in_progress and start it
          _ = core_module.mark_campaign_in_progress!(campaign)
          {:keep_state, data, internal_event(:start_campaign)}

        :in_progress ->
          # Campaign already in progress, resume it
          {:keep_state, data, internal_event(:resume_campaign)}
      end
    end
  end

  def handle_event(:internal, :resume_campaign, :initialization, data) do
    %{
      campaign_id: campaign_id,
      tenant_id: tenant_id,
      mechanism: mechanism,
      core_module: core_module
    } = data

    # TODO: query Astarte to verify that the cached status is consistent with our local status
    # (possibly spawning a separate task that queries Astarte and updates deployments)
    failed_count = core_module.get_failed_target_count(tenant_id, campaign_id)
    in_progress_count = core_module.get_in_progress_target_count(tenant_id, campaign_id)
    available_slots = core_module.available_slots(mechanism, in_progress_count)

    new_data = %{
      data
      | failed_count: failed_count,
        in_progress_count: in_progress_count,
        available_slots: available_slots
    }

    timeout_actions =
      tenant_id
      |> core_module.list_in_progress_targets(campaign_id)
      |> Enum.map(fn in_progress_target ->
        operation_id = core_module.get_operation_id(in_progress_target)

        # Side effect: receive updates for the target so we can track it
        core_module.subscribe_to_operation_updates!(operation_id)

        # Return the retry timeout action for the pending target
        setup_retry_timeout(tenant_id, in_progress_target, mechanism, core_module)
      end)

    # Fetch the next target
    actions = [internal_event(:fetch_next_target) | timeout_actions]

    # Start the rollout
    {:next_state, :execution, new_data, actions}
  end

  def handle_event(:internal, :start_campaign, :initialization, data) do
    %{mechanism: mechanism, core_module: core_module} = data

    available_slots = core_module.available_slots(mechanism, 0)

    new_data = %{
      data
      | failed_count: 0,
        in_progress_count: 0,
        available_slots: available_slots
    }

    # Start the rollout, fetching the next target
    {:next_state, :execution, new_data, internal_event(:fetch_next_target)}
  end

  # State: :execution (main campaign loop)

  def handle_event(:enter, _old_state, :execution, data) do
    Logger.info("Campaign #{data.campaign_id}: entering :execution state")

    :keep_state_and_data
  end

  def handle_event(:internal, :fetch_next_target, :execution, data) do
    %{
      tenant_id: tenant_id,
      campaign_id: campaign_id,
      campaign_data: campaign_data,
      core_module: core_module
    } = data

    case core_module.fetch_next_valid_target(tenant_id, campaign_id, campaign_data) do
      {:ok, target} ->
        # Do we have an available slot?
        if slot_available?(data) do
          {:keep_state_and_data, internal_event({:execute_on_target, target})}
        else
          # Wait for a slot to be available
          {:next_state, :wait_for_available_slot, data}
        end

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} ->
        # Are we finished?
        cond do
          # There are still some targets but none of them are online, wait for them
          core_module.has_idle_targets?(tenant_id, campaign_id) ->
            {:next_state, :wait_for_target, data}

          # We don't have any targets left, but we have to wait for in progress
          # ones to be finished
          targets_in_progress?(data) ->
            {:next_state, :wait_for_campaign_completion, data}

          # We're finished
          true ->
            {:next_state, :campaign_success, data}
        end
    end
  end

  def handle_event(:internal, {:execute_on_target, target}, :execution, data) do
    %{campaign_data: campaign_data, mechanism: mechanism, core_module: core_module} = data

    # We occupy a slot since we're rolling out to a new target
    new_data = occupy_slot(data)

    case core_module.do_operation(target, campaign_data, mechanism) do
      {:ok, :already_in_desired_state} ->
        {:keep_state, new_data, internal_event({:already_in_desired_state, target})}

      {:ok, target} ->
        {:keep_state, new_data, internal_event({:operation_started, target})}

      {:error, reason} ->
        if core_module.temporary_error?(reason) do
          {:keep_state, new_data, internal_event({:temporary_error, target, reason})}
        else
          {:keep_state, new_data, internal_event({:operation_failure, target, reason})}
        end
    end
  end

  def handle_event(:internal, {:already_in_desired_state, target}, :execution, data) do
    # The target already has the operation completed, just log and mark it as successful
    Logger.info("Device #{target.device_id} already in desired state")
    _ = data.core_module.mark_target_as_successful!(target)

    # We free up the slot since the target is considered completed
    new_data = free_up_slot(data)

    # We stay in this state and fetch the next target
    {:keep_state, new_data, internal_event(:fetch_next_target)}
  end

  def handle_event(:internal, {:operation_started, target}, :execution, data) do
    %{tenant_id: tenant_id, mechanism: mechanism, core_module: core_module} = data

    # Receive updates for the Deployment so we can track it
    operation_id = core_module.get_operation_id(target)
    core_module.subscribe_to_operation_updates!(operation_id)

    actions = [
      # Fetch the next target
      internal_event(:fetch_next_target),
      # Setup a timeout for the Deployment retry
      setup_retry_timeout(tenant_id, target, mechanism, core_module)
    ]

    {:keep_state_and_data, actions}
  end

  def handle_event(:internal, {:temporary_error, target, reason}, :execution, data) do
    reason
    |> data.core_module.error_message(target.device_id)
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

  def handle_event(:internal, {:operation_failure, target, reason}, :execution, data) do
    %{core_module: core_module} = data

    reason
    |> core_module.error_message(target.device_id)
    |> Logger.notice()

    # This is a permanent failure, so we mark the target as failed
    _ = core_module.mark_target_as_failed!(target)

    # We also increase failure and free up the slot since the target is in a final failure state
    new_data =
      data
      |> add_failure()
      |> free_up_slot()

    if failure_threshold_exceeded?(new_data, core_module) do
      {:next_state, :campaign_failure, new_data}
    else
      # We stay in this state and fetch the next target
      {:keep_state, new_data, internal_event(:fetch_next_target)}
    end
  end

  # State: :wait_for_available_slot

  def handle_event(:enter, _old_state, :wait_for_available_slot, data) do
    Logger.info("Campaign #{data.campaign_id}: waiting for available slot")

    # Just wait here, we will exit this state when we receive some updates on successful/failed
    :keep_state_and_data
  end

  # State: :wait_for_target

  def handle_event(:enter, _old_state, :wait_for_target, data) do
    Logger.info("Campaign #{data.campaign_id}: entering the :wait_for_target state")

    # TODO: start tracking offline targets so we can rollout them as soon as they come back online.
    # For now we just setup a state timeout and try to fetch the next target after 15 seconds
    action = {:state_timeout, 15_000, :check_target}
    {:keep_state_and_data, action}
  end

  def handle_event(:state_timeout, :check_target, :wait_for_target, data) do
    # Check to see if we have any new targets available
    {:next_state, :execution, data, internal_event(:fetch_next_target)}
  end

  # State: :wait_for_campaign_completion

  def handle_event(:enter, _old_state, :wait_for_campaign_completion, data) do
    Logger.info("Campaign #{data.campaign_id}: entering the :wait_for_campaign_completion state")

    :keep_state_and_data
  end

  # State: :campaign_failure

  def handle_event(:enter, _old_state, :campaign_failure, data) do
    %{campaign_id: campaign_id, tenant_id: tenant_id, core_module: core_module} = data

    Logger.notice("Campaign #{campaign_id} terminated with a failure")

    _ =
      tenant_id
      |> core_module.get_campaign!(campaign_id)
      |> core_module.mark_campaign_as_failed!()

    if targets_in_progress?(data) do
      # Here we don't terminate immediately, otherwise we would lose all the updates for the targets
      # that are currently in progress. If all the remaining targets reach a final state, we will
      # terminate while handling the relative :operation_completion internal event. Otherwise,
      # the executor will terminate after the grace period.
      action = {:state_timeout, to_timeout(hour: 1), :terminate_executor}
      {:keep_state_and_data, action}
    else
      # If we don't have any other in progress updates, we just terminate right away
      terminate_executor(campaign_id)
    end
  end

  def handle_event(:state_timeout, :terminate_executor, :campaign_failure, data) do
    # Grace period is over, terminate the executor
    terminate_executor(data.campaign_id)
  end

  # State: :campaign_success

  def handle_event(:enter, _old_state, :campaign_success, data) do
    %{campaign_id: campaign_id, tenant_id: tenant_id, core_module: core_module} = data

    Logger.info("Campaign #{campaign_id} terminated with a success")

    _ =
      tenant_id
      |> core_module.get_campaign!(campaign_id)
      |> core_module.mark_campaign_as_successful!()

    terminate_executor(campaign_id)
  end

  def handle_event(:internal, {:operation_success, operation}, _state, data) do
    %{tenant_id: tenant_id, campaign_id: campaign_id, core_module: core_module} = data

    Logger.info("Operation #{operation.id} succeeded")

    _ =
      tenant_id
      |> core_module.get_target_for_operation!(campaign_id, operation.device_id)
      |> core_module.mark_target_as_successful!()

    # Unsubscribe from operation updates since it's completed
    core_module.unsubscribe_to_operation_updates!(operation.id)

    # The Operation has finished, so we free up a slot
    new_data = free_up_slot(data)

    {:keep_state, new_data, internal_event(:operation_completion)}
  end

  def handle_event(:internal, {:operation_failure_event, operation}, state, data) do
    %{
      tenant_id: tenant_id,
      campaign_id: campaign_id,
      campaign_data: campaign_data,
      core_module: core_module
    } = data

    core_module.format_operation_failure_log(operation, campaign_data)

    _ =
      tenant_id
      |> core_module.get_target_for_operation!(campaign_id, operation.device_id)
      |> core_module.mark_target_as_failed!()

    # Unsubscribe from operation updates since it's in a terminal failure state
    core_module.unsubscribe_to_operation_updates!(operation.id)

    # Since the target was occupying a slot and we're marking it as failed, free up the slot
    new_data =
      data
      |> add_failure()
      |> free_up_slot()

    if state != :campaign_failure and failure_threshold_exceeded?(new_data, core_module) do
      # Enter the :campaign_failure state if it's the first time we exceed the threshold
      {:next_state, :campaign_failure, new_data}
    else
      # Otherwise, we just handle the Operation completion
      {:keep_state, new_data, internal_event(:operation_completion)}
    end
  end

  # Common Event Handlers

  def handle_event(:internal, :operation_completion, state, data) do
    cond do
      state == :wait_for_available_slot ->
        # If we were waiting for a free slot, we fetch the next target
        {:next_state, :execution, data, internal_event(:fetch_next_target)}

      state == :wait_for_campaign_completion and not targets_in_progress?(data) ->
        # We finished updating everything, go to the final state for the finishing touches
        {:next_state, :campaign_success, data}

      state == :campaign_failure and not targets_in_progress?(data) ->
        # We received all the updates for the remaining targets, we can terminate
        terminate_executor(data.campaign_id)

      true ->
        # Otherwise, we keep doing what we were doing
        :keep_state_and_data
    end
  end

  # Retry Logic

  def handle_event({:timeout, {:retry, _operation_id}}, target_id, _state, data) do
    %{tenant_id: tenant_id, mechanism: mechanism, core_module: core_module} = data

    target = core_module.get_target!(tenant_id, target_id)

    if core_module.can_retry?(target, mechanism) do
      {:keep_state_and_data, internal_event({:retry_target, target})}
    else
      {:keep_state_and_data, internal_event({:retry_threshold_exceeded, target})}
    end
  end

  def handle_event(:internal, {:retry_target, target}, _state, data) do
    %{
      tenant_id: tenant_id,
      mechanism: mechanism,
      campaign_data: campaign_data,
      core_module: core_module
    } = data

    target =
      target
      |> core_module.increase_retry_count!()
      |> core_module.update_target_latest_attempt!(DateTime.utc_now())

    case core_module.retry_operation(target, campaign_data) do
      :ok ->
        # Setup a timeout for the Operation retry
        action = setup_retry_timeout(tenant_id, target, mechanism, core_module)

        {:keep_state_and_data, action}

      {:error, reason} ->
        reason
        |> core_module.error_message(target.device_id)
        |> Logger.notice()

        # We don't check if the error is temporary or not, since by definition
        # it shouldn't be because we already have a successful pending
        # Operation request if we're here. If we failed during a retry, we just
        # schedule another timeout after the retry timeout period, and we'll do
        # another retry (in this case we're counting them towards the retry
        # count since the Operation, differently from the case where we fail
        # during the initial rollout)
        # TODO: evaluate if this is the desired behaviour
        action = setup_retry_timeout(tenant_id, target, mechanism, core_module)

        {:keep_state_and_data, action}
    end
  end

  def handle_event(:internal, {:retry_threshold_exceeded, target}, _state, data) do
    %{tenant_id: tenant_id, core_module: core_module} = data

    Logger.notice("Target #{target.device_id} exhausted all retries")

    operation_id = core_module.get_operation_id(target)
    _ = core_module.mark_operation_as_timed_out!(tenant_id, operation_id)

    # Unsubscribe from operation updates since we've given up on retries
    core_module.unsubscribe_to_operation_updates!(operation_id)

    :keep_state_and_data
  end

  # Helper Functions

  def setup_retry_timeout(tenant_id, target, mechanism, core_module) do
    # Create a generic timeout identified by the Operation (Deployment or Update) ID
    # so we can cancel it if the Deployment gets updated with an ack. Note that this
    # works correctly even if the timeout is already expired (e.g. when resuming a
    # campaign) since Core.pending_request_timeout_ms will return 0 in that case,
    # and setting up a 0 timer will enqueue the timer action event immediately.

    operation_id = core_module.get_operation_id(target)
    timeout_ms = core_module.pending_request_timeout_ms(target, mechanism)

    {{:timeout, {:retry, {tenant_id, operation_id}}}, timeout_ms, target.id}
  end

  def cancel_retry_timeout(tenant_id, operation_id) do
    # Cancel the pending retry timer
    {{:timeout, {:retry, {tenant_id, operation_id}}}, :cancel}
  end

  def internal_event(payload) do
    {:next_event, :internal, payload}
  end

  def terminate_executor(campaign_id) do
    Logger.info("Terminating executor process for Campaign #{campaign_id}")

    {:stop, :normal}
  end

  # Data manipulation

  def occupy_slot(data) do
    %{
      data
      | available_slots: data.available_slots - 1,
        in_progress_count: data.in_progress_count + 1
    }
  end

  def free_up_slot(data) do
    %{
      data
      | available_slots: data.available_slots + 1,
        in_progress_count: data.in_progress_count - 1
    }
  end

  def add_failure(data) do
    %{
      data
      | failed_count: data.failed_count + 1
    }
  end

  def failure_threshold_exceeded?(data, core_module) do
    core_module.failure_threshold_exceeded?(
      data.target_count,
      data.failed_count,
      data.mechanism
    )
  end

  def slot_available?(data), do: data.available_slots > 0

  def targets_in_progress?(data), do: data.in_progress_count > 0

  defmacro __using__(opts) do
    core_module = Keyword.fetch!(opts, :core)

    quote location: :keep do
      @behaviour Edgehog.Campaigns.Executors.LazyBatch

      use GenStateMachine,
        restart: :transient,
        callback_mode: [:handle_event_function, :state_enter]

      alias Edgehog.Campaigns.Executors.LazyBatch
      alias Edgehog.Campaigns.Executors.LazyBatch, as: Data

      require Logger

      @core_module unquote(core_module)

      # Public API

      def start_link(args) do
        name = args[:name] || __MODULE__

        GenStateMachine.start_link(__MODULE__, args, name: name)
      end

      # GenStateMachine Callbacks

      @impl GenStateMachine
      def init(opts) do
        tenant_id = Keyword.fetch!(opts, :tenant_id)
        campaign_id = Keyword.fetch!(opts, :campaign_id)

        data = %Data{
          campaign_id: campaign_id,
          tenant_id: tenant_id,
          core_module: @core_module
        }

        if opts[:wait_for_start_execution] do
          # Use this to manually start the executor in tests
          {:ok, :wait_for_start_execution, data}
        else
          {:ok, :initialization, data, internal_event(:init_data)}
        end
      end

      @impl GenStateMachine
      def handle_event(:info, message, state, data) do
        handle_info(message, state, data)
      end

      def handle_event(event_type, event_content, state, data) do
        Data.handle_event(
          event_type,
          event_content,
          state,
          data
        )
      end

      # Helper Functions - delegated to LazyBatch module

      defdelegate setup_retry_timeout(tenant_id, target, mechanism, core_module),
        to: Data

      defdelegate cancel_retry_timeout(tenant_id, operation_id),
        to: Data

      defdelegate internal_event(payload), to: Data
      defdelegate terminate_executor(campaign_id), to: Data
      defdelegate occupy_slot(data), to: Data
      defdelegate free_up_slot(data), to: Data
      defdelegate add_failure(data), to: Data

      defdelegate failure_threshold_exceeded?(data, core_module),
        to: Data

      defdelegate slot_available?(data), to: Data
      defdelegate targets_in_progress?(data), to: Data
    end
  end
end
