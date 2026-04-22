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

defmodule Edgehog.Campaigns.Executors.DeploymentDeleteExecutorTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL
  alias Edgehog.Astarte.Device.DeploymentCommandMock
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.CampaignMechanism.Core, as: MechanismCore
  alias Edgehog.Campaigns.CampaignMechanism.DeploymentDelete
  alias Edgehog.Campaigns.CampaignMechanism.DeploymentDelete.Executor
  alias Edgehog.Containers
  alias Edgehog.Containers.Deployment

  setup do
    stub(DeploymentCommandMock, :send_deployment_command, fn _client, _device_id, _data ->
      :ok
    end)

    %{tenant: tenant_fixture()}
  end

  describe "Executor immediately terminates" do
    test "when a deployment delete campaign has no targets", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :deployment_delete)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(campaign)

      assert_normal_exit(pid, ref)
    end

    test "when deployment delete campaign is already marked as failed", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_delete)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [])

      mechanism = campaign.campaign_mechanism.value
      [target] = campaign.campaign_targets
      _ = MechanismCore.mark_target_as_failed!(mechanism, target)
      _ = MechanismCore.mark_campaign_as_failed!(mechanism, campaign)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(campaign)

      assert_normal_exit(pid, ref)
    end

    test "when deployment delete campaign is already marked as successful", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_delete)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [])

      mechanism = campaign.campaign_mechanism.value

      [target] = campaign.campaign_targets
      _ = MechanismCore.mark_target_as_successful!(mechanism, target)
      _ = MechanismCore.mark_campaign_as_successful!(mechanism, campaign)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(campaign)

      assert_normal_exit(pid, ref)
    end
  end

  describe "Executor resumes :in_progress deployment delete campaign" do
    test "when it already has `max_in_progress_operations` pending delete operations", %{
      tenant: tenant
    } do
      target_count = Enum.random(10..20)
      max_in_progress_operations = Enum.random(2..5)

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :deployment_delete,
          campaign_mechanism: [max_in_progress_operations: max_in_progress_operations],
          tenant: tenant
        )

      pid = start_executor!(campaign)

      # Wait for the Executor to arrive at :wait_for_available_slot
      wait_for_state(pid, :wait_for_available_slot, 1000)

      # Stop the executor
      stop_supervised(Executor)

      # Start another executor for the same deployment campaign
      resumed_pid = start_executor!(campaign)

      # Expect no new Deploy Requests
      _ = expect_deployment_delete_requests_and_send_sync(0)

      # Expect the Executor to arrive at :wait_for_available_slot
      wait_for_state(resumed_pid, :wait_for_available_slot)
    end

    test "when it is waiting for completion", %{tenant: tenant} do
      target_count = Enum.random(2..20)

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :deployment_delete,
          campaign_mechanism: [max_in_progress_operations: target_count],
          tenant: tenant
        )

      pid = start_executor!(campaign)

      # Wait for the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion, 1000)

      # Stop the executor
      stop_supervised(Executor)

      # Start another executor for the same deployment campaign
      resumed_pid = start_executor!(campaign)

      # Expect no Deploy Requests
      _ = expect_deployment_delete_requests_and_send_sync(0)

      # Expect the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(resumed_pid, :wait_for_campaign_completion)
    end
  end

  describe "Executor sends" do
    test "all target Delete Deployment Requests in parallel if there are enough available slots",
         %{
           tenant: tenant
         } do
      target_count = Enum.random(2..20)

      campaign =
        target_count
        |> campaign_with_targets_fixture(
          mechanism_type: :deployment_delete,
          campaign_mechanism: [max_in_progress_operations: target_count],
          tenant: tenant
        )
        |> Ash.load!(campaign_targets: [device: [:device_id]])

      parent = self()
      ref = make_ref()
      target_device_ids = Enum.map(campaign.campaign_targets, & &1.device.device_id)

      # Expect target_count deployment calls and send back a message for each device
      expect(
        DeploymentCommandMock,
        :send_deployment_command,
        target_count,
        # TODO: assert that we' receiving the correct data!
        fn _client, device_id, _data ->
          send_sync(parent, {ref, device_id})
          :ok
        end
      )

      pid = start_executor!(campaign)

      # Wait for all the device sync messages
      target_device_ids
      |> Enum.map(&{ref, &1})
      |> wait_for_sync!()

      # Expect the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion)
    end

    test "at most `max_in_progress_operations` Delete Deployment Requests", %{tenant: tenant} do
      target_count = Enum.random(10..20)
      max_in_progress_operations = Enum.random(2..5)

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :deployment_delete,
          campaign_mechanism: [max_in_progress_operations: max_in_progress_operations],
          tenant: tenant
        )

      # Expect max_in_progress_operations Deploy Requests
      ref = expect_deployment_delete_requests_and_send_sync(max_in_progress_operations)

      pid = start_executor!(campaign)

      # Wait for max_in_progress_operations sync messages
      ref
      |> repeat(max_in_progress_operations)
      |> wait_for_sync!()

      # Expect the Executor to arrive at :wait_for_available_slot
      wait_for_state(pid, :wait_for_available_slot)
    end

    test "Delete Deployment Requests only to online targets", %{tenant: tenant} do
      target_count = Enum.random(10..20)
      # We want at least 1 offline target to test that we arrive in :wait_for_target
      offline_count = Enum.random(1..target_count)
      online_count = target_count - offline_count

      campaign =
        target_count
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :deployment_delete)
        |> Ash.load!(:campaign_targets)

      {offline_targets, online_targets} =
        Enum.split(campaign.campaign_targets, offline_count)

      # Mark the online targets as online
      deployment_device_online_for_targets(online_targets, true)
      # Mark the offline targets as offline
      deployment_device_online_for_targets(offline_targets, false)

      # Expect online_count calls to the mock
      ref = expect_deployment_delete_requests_and_send_sync(online_count)

      pid = start_executor!(campaign)

      # Wait for online_count sync messages
      ref
      |> repeat(online_count)
      |> wait_for_sync!()

      # Expect the Executor to arrive at :wait_for_target
      wait_for_state(pid, :wait_for_target)
    end
  end

  describe "Executor receiving a Deployment update" do
    setup %{tenant: tenant} do
      target_count = 10
      max_deployments = 5

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :deployment_delete,
          campaign_mechanism: [max_in_progress_operations: max_deployments],
          tenant: tenant
        )

      parent = self()

      expect(
        DeploymentCommandMock,
        :send_deployment_command,
        max_deployments,
        fn _client,
           _device_id,
           %Edgehog.Astarte.Device.DeploymentCommand.RequestData{
             deployment_id: deployment_id,
             command: "Delete"
           } ->
          send(parent, {:deployment_target, deployment_id})
          :ok
        end
      )

      pid = start_executor!(campaign)

      # Wait for the Executor to arrive at :wait_for_available_slot
      wait_for_state(pid, :wait_for_available_slot)

      # Verify that all the expectations we defined until now were called
      verify!()

      # Extract Deployment for a target that received the Deployment request
      deployment_id =
        receive do
          {:deployment_target, deployment_id} ->
            deployment_id
        after
          1000 -> flunk()
        end

      # Throw away the other messages
      flush_messages()

      {:ok, executor_pid: pid, deployment_id: deployment_id}
    end

    test "frees up slot if Deployment is deleted", ctx do
      %{
        executor_pid: pid,
        deployment_id: deployment_id,
        tenant: tenant
      } = ctx

      # Expect another call to the mock since a slot has freed up
      ref = expect_deployment_delete_requests_and_send_sync()

      trigger_destroy_and_gc!(tenant, deployment_id)

      wait_for_sync!(ref)

      # Wait for the Executor to arrive at :wait_for_available_slot
      wait_for_state(pid, :wait_for_available_slot)
    end

    test "frees up slot if the deployment times out", ctx do
      %{
        executor_pid: pid,
        deployment_id: deployment_id,
        tenant: tenant
      } = ctx

      # Expect another call to the mock since a slot has freed up
      ref = expect_deployment_delete_requests_and_send_sync()

      timeout_deployment!(tenant, deployment_id)

      wait_for_sync!(ref)

      # Wait for the Executor to arrive at :wait_for_available_slot
      wait_for_state(pid, :wait_for_available_slot)
    end
  end

  describe "Executor marks deployment delete campaign as successful" do
    setup %{tenant: tenant} do
      target_count = 5
      # 20 < x <= 70
      max_failure_percentage = 20 + :rand.uniform() * 50

      release = release_fixture(system_models: 1, tenant: tenant)

      campaign =
        campaign_with_targets_fixture(target_count,
          release_id: release.id,
          mechanism_type: :deployment_delete,
          campaign_mechanism: [
            max_in_progress_operations: target_count,
            max_failure_percentage: max_failure_percentage
          ],
          tenant: tenant.tenant_id
        )

      %{pid: pid, ref: ref} =
        start_and_monitor_executor!(campaign, start_execution: false)

      ctx = [
        release: release,
        executor_pid: pid,
        max_failure_percentage: max_failure_percentage,
        monitor_ref: ref,
        target_count: target_count,
        campaign_id: campaign.id
      ]

      {:ok, ctx}
    end

    test "if all targets are successful", ctx do
      %{
        executor_pid: pid,
        monitor_ref: ref,
        campaign_id: campaign_id,
        tenant: tenant
      } = ctx

      start_execution(pid)

      # Wait for the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion)

      trigger_destroy_for_pending_deployments(tenant, campaign_id)

      assert_normal_exit(pid, ref)
      assert_campaign_outcome(tenant, campaign_id, :success)
    end

    test "if just less than `max_failure_percentage` targets fail", ctx do
      %{
        executor_pid: pid,
        max_failure_percentage: max_failure_percentage,
        monitor_ref: ref,
        target_count: target_count,
        campaign_id: campaign_id,
        tenant: tenant
      } = ctx

      start_execution(pid)

      # Wait for the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion)

      deployment_ids =
        %DeploymentDelete{}
        |> MechanismCore.list_in_progress_targets(tenant.tenant_id, campaign_id)
        |> Enum.map(& &1.deployment_id)

      failing_target_count = max_failed_targets_for_success(target_count, max_failure_percentage)

      {failing_deployment_ids, successful_deployment_ids} =
        Enum.split(deployment_ids, failing_target_count)

      Enum.each(failing_deployment_ids, &timeout_deployment!(tenant, &1))
      Enum.each(successful_deployment_ids, &trigger_destroy_and_gc!(tenant, &1))
      assert_normal_exit(pid, ref, 6000)
      assert_campaign_outcome(tenant, campaign_id, :success)
    end
  end

  describe "Executor marks campaign as failed if `max_failure_percentage` is exceeded" do
    setup %{tenant: tenant} do
      target_count = Enum.random(10..20)
      # 20 < x <= 70
      max_failure_percentage = 20 + :rand.uniform() * 50

      # The minimum number of targets that have to fail to trigger a failure
      failing_target_count = min_failed_targets_for_failure(target_count, max_failure_percentage)

      release =
        release_fixture(
          system_models: 1,
          tenant: tenant
        )

      campaign =
        campaign_with_targets_fixture(target_count,
          release_id: release.id,
          mechanism_type: :deployment_delete,
          campaign_mechanism: [
            max_in_progress_operations: target_count,
            max_failure_percentage: max_failure_percentage
          ],
          tenant: tenant
        )

      %{pid: pid, ref: ref} =
        start_and_monitor_executor!(campaign, start_execution: false)

      ctx = [
        executor_pid: pid,
        failing_target_count: failing_target_count,
        monitor_ref: ref,
        campaign_id: campaign.id
      ]

      {:ok, ctx}
    end

    test "by failed Stop Operations on Deployments", ctx do
      %{
        executor_pid: pid,
        failing_target_count: failing_target_count,
        monitor_ref: ref,
        campaign_id: campaign_id,
        tenant: tenant
      } = ctx

      # Start the execution
      start_execution(pid)

      # Wait for the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion)

      {failing_targets, remaining_targets} =
        %DeploymentDelete{}
        |> MechanismCore.list_in_progress_targets(tenant.tenant_id, campaign_id)
        |> Enum.split(failing_target_count)

      # Produce failing_target_count failures
      Enum.each(failing_targets, fn target ->
        timeout_deployment!(tenant, target.deployment_id)
      end)

      # Now the Executor should arrive at :campaign_failure, but not terminate yet
      wait_for_state(pid, :campaign_failure)

      # Make the remaining targets reach a final state, some with success, some with failure
      # The random count guarantees that we have at least one success and one failure
      remaining_failing_count = Enum.random(1..(length(remaining_targets) - 1))

      {remaining_failing_targets, remaining_successful_targets} =
        Enum.split(remaining_targets, remaining_failing_count)

      Enum.each(remaining_successful_targets, fn target ->
        trigger_destroy_and_gc!(tenant, target.deployment_id)
      end)

      Enum.each(remaining_failing_targets, fn target ->
        timeout_deployment!(tenant, target.deployment_id)
      end)

      # Now the Executor should terminate
      assert_normal_exit(pid, ref)
      assert_campaign_outcome(tenant, campaign_id, :failure)
    end

    test "by targets failing during the initial rollout with a non-temporary API failure", ctx do
      %{
        executor_pid: pid,
        failing_target_count: failing_target_count,
        monitor_ref: ref,
        campaign_id: campaign_id,
        tenant: tenant
      } = ctx

      # Expect failing_target_count calls to the mock and return a non-temporary error
      expect(
        DeploymentCommandMock,
        :send_deployment_command,
        failing_target_count,
        fn _client, _device_id, _data ->
          status = Enum.random(400..499)
          {:error, %Astarte.Client.APIError{status: status, response: "F"}}
        end
      )

      # Start the execution
      start_execution(pid)

      assert_normal_exit(pid, ref, 3000)
      assert_campaign_outcome(tenant, campaign_id, :failure)
    end
  end

  describe "pause and resume deployment delete executor" do
    test "pause suppresses new delete requests and resume restarts rollout", %{tenant: tenant} do
      max_updates = 3

      campaign =
        campaign_with_targets_fixture(8,
          mechanism_type: :deployment_delete,
          campaign_mechanism: [max_in_progress_operations: max_updates],
          tenant: tenant
        )

      # Expect initial max_updates delete requests
      init_ref = expect_deployment_delete_requests_and_send_sync(max_updates)

      pid = start_executor!(campaign)

      # Wait for initial requests
      wait_for_sync!(repeat(init_ref, max_updates))

      # Arrive at waiting for available slot
      wait_for_state(pid, :wait_for_available_slot)

      # While paused, no further delete requests should be sent
      expect(DeploymentCommandMock, :send_deployment_command, 0, fn _client, _device_id, _data ->
        :ok
      end)

      # Monitor the executor to detect termination
      ref = Process.monitor(pid)

      # Reload campaign to get in_progress status before pausing
      campaign = Ash.get!(Campaign, campaign.id, tenant: tenant)

      # Pause via the Campaigns context (triggers PubSub notification)
      {:ok, _paused_campaign} = Campaigns.pause_campaign(campaign)

      # Ensure we are in wait_for_campaign_paused state (waiting for in-progress to complete)
      wait_for_state(pid, :wait_for_campaign_paused)

      # Mark all pending deployments as done so the executor can proceed to paused state and terminate
      %{tenant_id: tenant_id, id: campaign_id} = campaign

      %DeploymentDelete{}
      |> MechanismCore.list_in_progress_targets(tenant_id, campaign_id)
      |> Enum.each(fn target ->
        trigger_destroy_and_gc!(tenant, target.deployment_id)
      end)

      # Wait for executor to terminate (it marks campaign as paused and exits)
      assert_normal_exit(pid, ref)

      # Now resume - expect new delete requests for remaining targets
      # (8 total - 3 completed = 5 remaining, capped at max_updates = 3)
      resume_ref = expect_deployment_delete_requests_and_send_sync(max_updates)

      # Reload campaign to get paused status
      paused_campaign = Ash.get!(Campaign, campaign.id, tenant: tenant)

      # Resume via the Campaigns context (starts a NEW executor)
      {:ok, _resumed_campaign} = Campaigns.resume_campaign(paused_campaign)

      # Get the new executor's pid from the registry
      executor_id = {tenant_id, campaign_id, :deployment_delete}
      [{new_pid, _}] = Registry.lookup(Edgehog.Campaigns.ExecutorRegistry, executor_id)

      # Allow the new executor to use test resources
      allow_test_resources(new_pid)

      # Manually start execution for the new executor
      start_execution(new_pid)

      wait_for_sync!(repeat(resume_ref, max_updates))

      # Back to waiting for available slot with the new executor
      wait_for_state(new_pid, :wait_for_available_slot)
    end

    test "campaign can complete while paused", %{tenant: tenant} do
      campaign =
        campaign_with_targets_fixture(4,
          mechanism_type: :deployment_delete,
          campaign_mechanism: [max_in_progress_operations: 4],
          tenant: tenant
        )

      pid = start_executor!(campaign)

      # Reach completion wait
      wait_for_state(pid, :wait_for_campaign_completion)

      # Monitor the process before pausing
      ref = Process.monitor(pid)

      # Reload campaign to get in_progress status before pausing
      campaign = Ash.get!(Campaign, campaign.id, tenant: tenant)

      # Pause via the Campaigns context (triggers PubSub notification)
      {:ok, _paused_campaign} = Campaigns.pause_campaign(campaign)

      # Executor transitions to wait_for_campaign_paused
      wait_for_state(pid, :wait_for_campaign_paused)

      # Mark all pending as destroyed; executor will transition to campaign_paused, then campaign_success
      %DeploymentDelete{}
      |> MechanismCore.list_in_progress_targets(campaign.tenant_id, campaign.id)
      |> Enum.each(fn target ->
        trigger_destroy_and_gc!(tenant, target.deployment_id)
      end)

      # Process should terminate normally (completing successfully while paused)
      assert_normal_exit(pid, ref)
    end
  end

  defp max_failed_targets_for_success(target_count, max_failure_percentage) do
    # Returns the maximum number of targets that can fail and still produce a successful campaign
    floor(target_count * max_failure_percentage / 100)
  end

  defp min_failed_targets_for_failure(target_count, max_failure_percentage) do
    # Returns the minimum number of targets that must fail to produce a failed campaign
    1 + max_failed_targets_for_success(target_count, max_failure_percentage)
  end

  defp send_sync(dest, ref) do
    send(dest, {:sync, ref})
  end

  defp wait_for_sync!([] = _refs) do
    :ok
  end

  defp wait_for_sync!(refs) when is_list(refs) do
    receive do
      {:sync, ref} ->
        if ref in refs do
          refs
          |> List.delete(ref)
          |> wait_for_sync!()
        else
          flunk("Received unexpected ref: #{inspect(ref)}")
        end
    after
      1000 -> flunk("Sync timeout, not received: #{inspect(refs)}")
    end
  end

  defp wait_for_sync!(ref) do
    assert_receive {:sync, ^ref}, 1000
  end

  defp wait_for_state(executor_pid, state, timeout \\ 1000) do
    start_time = DateTime.utc_now()

    loop_until_state!(executor_pid, state, start_time, timeout)
  end

  defp loop_until_state!(executor_pid, state, _start_time, remaining_time) when remaining_time <= 0 do
    {actual_state, _data} = :sys.get_state(executor_pid)
    flunk("State #{state} not reached, last state: #{actual_state}")
  end

  defp loop_until_state!(executor_pid, state, start_time, _remaining_time) do
    case :sys.get_state(executor_pid) do
      {^state, _data} ->
        :ok

      _other ->
        Process.sleep(100)
        remaining_time = DateTime.diff(start_time, DateTime.utc_now(), :millisecond)
        loop_until_state!(executor_pid, state, start_time, remaining_time)
    end
  end

  @executor_allowed_mocks [
    Edgehog.Astarte.Device.DeviceStatusMock,
    DeploymentCommandMock
  ]

  defp start_and_monitor_executor!(campaign, opts \\ []) do
    # We don't start the execution so we can monitor it before it completes
    pid = start_executor!(campaign, start_execution: false)
    ref = Process.monitor(pid)
    # After we monitor it, we can (maybe) manually start it
    maybe_start_execution(pid, opts)

    %{pid: pid, ref: ref}
  end

  defp start_executor!(campaign, opts \\ []) do
    args = executor_args(campaign)

    {Executor, args}
    |> start_supervised!()
    |> allow_test_resources()
    |> maybe_start_execution(opts)
  end

  defp executor_args(campaign) do
    [
      tenant_id: campaign.tenant_id,
      campaign_id: campaign.id,
      # This ensures the Executor waits for our :start_execution message to start
      wait_for_start_execution: true
    ]
  end

  defp allow_test_resources(pid) do
    # Allow all relevant Mox mocks to be called by the Executor process
    Enum.each(@executor_allowed_mocks, &Mox.allow(&1, self(), pid))

    # Also allow the pid to use SQL Sandbox
    SQL.Sandbox.allow(Repo, self(), pid)

    pid
  end

  defp maybe_start_execution(pid, opts) do
    # We start the execution by default, but the test can decide to manually start it
    # from the outside by passing [start_execution: false] in the start options
    if Keyword.get(opts, :start_execution, true) do
      start_execution(pid)
    else
      pid
    end
  end

  def start_execution(pid) do
    # Unlock an Executor that was started with wait_for_start_execution: true
    send(pid, :start_execution)

    pid
  end

  defp expect_deployment_delete_requests_and_send_sync(count \\ 1) do
    # Asserts that count Deploy Requests where sent and sends a sync message for
    # each of them Returns the ref contained in the sync message
    parent = self()
    ref = make_ref()

    expect(DeploymentCommandMock, :send_deployment_command, count, fn _client, _device_id, _data ->
      # Send the sync
      send_sync(parent, ref)
      :ok
    end)

    ref
  end

  defp trigger_destroy_and_gc!(tenant, deployment_id) do
    Deployment
    |> Ash.get!(deployment_id, tenant: tenant)
    |> Ash.Changeset.for_destroy(:destroy_and_gc)
    |> Ash.destroy(tenant: tenant)
  end

  defp timeout_deployment!(tenant, deployment_id) do
    assert {:ok, deployment} =
             deployment_id
             |> Containers.fetch_deployment!(tenant: tenant)
             |> Containers.mark_deployment_as_timed_out(tenant: tenant)

    deployment
  end

  defp deployment_device_online_for_targets(targets, online) do
    targets
    |> Ash.load!(:device)
    |> Enum.each(fn target ->
      Ash.update!(target.device, %{online: online}, action: :from_device_status)
    end)
  end

  defp trigger_destroy_for_pending_deployments(tenant, campaign_id) do
    %DeploymentDelete{}
    |> MechanismCore.list_in_progress_targets(tenant.tenant_id, campaign_id)
    |> Enum.each(fn target ->
      trigger_destroy_and_gc!(tenant, target.deployment_id)
    end)
  end

  defp assert_campaign_outcome(tenant, id, outcome) do
    campaign = MechanismCore.get_campaign!(%DeploymentDelete{}, tenant.tenant_id, id)
    assert campaign.status == :finished
    assert campaign.outcome == outcome
  end

  defp repeat(value, n) do
    # Repeats value for n times and returns a list of them
    fn -> value end
    |> Stream.repeatedly()
    |> Enum.take(n)
  end

  defp assert_normal_exit(pid, ref, timeout \\ 1000) do
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal},
                   timeout,
                   "Process did not terminate with reason :normal as expected"
  end

  defp flush_messages do
    receive do
      _msg -> flush_messages()
    after
      10 -> :ok
    end
  end
end
