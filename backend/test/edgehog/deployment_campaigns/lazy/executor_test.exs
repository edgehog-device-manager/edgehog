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

defmodule Edgehog.DeploymentCampaigns.Lazy.ExecutorTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DeploymentCampaignsFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL
  alias Edgehog.Astarte.Device.CreateDeploymentRequestMock
  alias Edgehog.Containers
  alias Edgehog.DeploymentCampaigns.DeploymentCampaign
  alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core
  alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Executor

  setup do
    stub(CreateDeploymentRequestMock, :send_create_deployment_request, fn _client, _device_id, _data ->
      :ok
    end)

    %{tenant: tenant_fixture()}
  end

  describe "Lazy.Executor immediately terminates" do
    test "when a campaign has no targets", %{tenant: tenant} do
      deployment_campaign = deployment_campaign_fixture(tenant: tenant)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(deployment_campaign)

      assert_normal_exit(pid, ref)
    end

    test "when campaign is already marked as failed", %{tenant: tenant} do
      deployment_campaign =
        1
        |> deployment_campaign_with_targets_fixture(tenant: tenant)
        |> Ash.load!(:deployment_targets)

      [target] = deployment_campaign.deployment_targets
      _ = Core.mark_target_as_failed!(target)
      _ = Core.mark_deployment_campaign_as_failed!(deployment_campaign)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(deployment_campaign)

      assert_normal_exit(pid, ref)
    end

    test "when campaign is already marked as successful", %{tenant: tenant} do
      deployment_campaign =
        1
        |> deployment_campaign_with_targets_fixture(tenant: tenant)
        |> Ash.load!(:deployment_targets)

      [target] = deployment_campaign.deployment_targets
      _ = Core.mark_target_as_successful!(target)
      _ = Core.mark_deployment_campaign_as_successful!(deployment_campaign)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(deployment_campaign)

      assert_normal_exit(pid, ref)
    end
  end

  describe "Lazy.Executor resumes :in_progress campaign" do
    test "when it already has max_in_progress_deployments pending deployments", %{tenant: tenant} do
      target_count = Enum.random(10..20)
      max_in_progress_deployments = Enum.random(2..5)

      deployment_campaign =
        deployment_campaign_with_targets_fixture(target_count,
          deployment_mechanism: [max_in_progress_deployments: max_in_progress_deployments],
          tenant: tenant
        )

      pid = start_executor!(deployment_campaign)

      # Wait for the Executor to arrive at :wait_for_available_slot
      wait_for_state(pid, :wait_for_available_slot, 1000)

      # Stop the executor
      stop_supervised(Executor)

      # Start another executor for the same deployment campaign
      resumed_pid = start_executor!(deployment_campaign)

      # Expect no new Deploy Requests
      _ = expect_deployment_requests_and_send_sync(0)

      # Expect the Executor to arrive at :wait_for_available_slot
      wait_for_state(resumed_pid, :wait_for_available_slot)
    end

    test "when it is waiting for completion", %{tenant: tenant} do
      target_count = Enum.random(2..20)

      deployment_campaign =
        deployment_campaign_with_targets_fixture(target_count,
          deployment_mechanism: [max_in_progress_deployments: target_count],
          tenant: tenant
        )

      pid = start_executor!(deployment_campaign)

      # Wait for the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion, 1000)

      # Stop the executor
      stop_supervised(Executor)

      # Start another executor for the same deployment campaign
      resumed_pid = start_executor!(deployment_campaign)

      # Expect no Deploy Requests
      _ = expect_deployment_requests_and_send_sync(0)

      # Expect the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(resumed_pid, :wait_for_campaign_completion)
    end
  end

  describe "Lazy.Executor sends" do
    test "all target Deploy Requests in parallel if there are enough available slots", %{
      tenant: tenant
    } do
      target_count = Enum.random(2..20)

      deployment_campaign =
        target_count
        |> deployment_campaign_with_targets_fixture(
          deployment_mechanism: [max_in_progress_deployments: target_count],
          tenant: tenant
        )
        |> Ash.load!(deployment_targets: [device: [:device_id]])

      parent = self()
      ref = make_ref()
      target_device_ids = Enum.map(deployment_campaign.deployment_targets, & &1.device.device_id)

      # Expect target_count deployment calls and send back a message for each device
      expect(
        CreateDeploymentRequestMock,
        :send_create_deployment_request,
        target_count,
        # TODO: assert that we' receiving the correct data!
        fn _client, device_id, _data ->
          send_sync(parent, {ref, device_id})
          :ok
        end
      )

      pid = start_executor!(deployment_campaign)

      # Wait for all the device sync messages
      target_device_ids
      |> Enum.map(&{ref, &1})
      |> wait_for_sync!()

      # Expect the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion)
    end

    test "at most max_in_progress_deployments Deployment Requests", %{tenant: tenant} do
      target_count = Enum.random(10..20)
      max_in_progress_deployments = Enum.random(2..5)

      deployment_campaign =
        deployment_campaign_with_targets_fixture(target_count,
          deployment_mechanism: [max_in_progress_deployments: max_in_progress_deployments],
          tenant: tenant
        )

      # Expect max_in_progress_deployments Deploy Requests
      ref = expect_deployment_requests_and_send_sync(max_in_progress_deployments)

      pid = start_executor!(deployment_campaign)

      # Wait for max_in_progress_deployments sync messages
      ref
      |> repeat(max_in_progress_deployments)
      |> wait_for_sync!()

      # Expect the Executor to arrive at :wait_for_available_slot
      wait_for_state(pid, :wait_for_available_slot)
    end

    test "Deployment Requests only to online targets", %{tenant: tenant} do
      target_count = Enum.random(10..20)
      # We want at least 1 offline target to test that we arrive in :wait_for_target
      offline_count = Enum.random(1..target_count)
      online_count = target_count - offline_count

      deployment_campaign =
        target_count
        |> deployment_campaign_with_targets_fixture(tenant: tenant)
        |> Ash.load!(:deployment_targets)

      {offline_targets, online_targets} =
        Enum.split(deployment_campaign.deployment_targets, offline_count)

      # Mark the online targets as online
      deployment_device_online_for_targets(online_targets, true)
      # Mark the offline targets as offline
      deployment_device_online_for_targets(offline_targets, false)

      # Expect online_count calls to the mock
      ref = expect_deployment_requests_and_send_sync(online_count)

      pid = start_executor!(deployment_campaign)

      # Wait for online_count sync messages
      ref
      |> repeat(online_count)
      |> wait_for_sync!()

      # Expect the Executor to arrive at :wait_for_target
      wait_for_state(pid, :wait_for_target)
    end
  end

  describe "Lazy.Executor receiving a Deployment update" do
    setup %{tenant: tenant} do
      target_count = 10
      max_deployments = 5

      deployment_campaign =
        deployment_campaign_with_targets_fixture(target_count,
          deployment_mechanism: [max_in_progress_deployments: max_deployments],
          tenant: tenant
        )

      parent = self()

      expect(
        CreateDeploymentRequestMock,
        :send_create_deployment_request,
        max_deployments,
        fn _client, _device_id, data ->
          %{id: deployment_id} = data
          # Since we don't know _which_ target will receive the request, we send it back from here
          send(parent, {:deployment_target, deployment_id})
          :ok
        end
      )

      pid = start_executor!(deployment_campaign)

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

    for status <- [:started, :starting, :stopped, :stopping, :error] do
      test "frees up slot if Deployment state is #{status}", ctx do
        %{
          executor_pid: pid,
          deployment_id: deployment_id,
          tenant: tenant
        } = ctx

        # Expect another call to the mock since a slot has freed up
        ref = expect_deployment_requests_and_send_sync()

        update_deployment_state!(tenant, deployment_id, unquote(status))

        wait_for_sync!(ref)

        # Wait for the Executor to arrive at :wait_for_available_slot
        wait_for_state(pid, :wait_for_available_slot)
      end
    end

    for status <- [:pending, :sent] do
      test "doesn't free up slots if Deployment status is #{status}", ctx do
        %{
          executor_pid: pid,
          deployment_id: deployment_id,
          tenant: tenant
        } = ctx

        # Expect no calls to the mock
        expect(CreateDeploymentRequestMock, :send_create_deployment_request, 0, fn _client, _device_id, _data ->
          :ok
        end)

        update_deployment_state!(tenant, deployment_id, unquote(status))

        # Expect the executor to remain in the :wait_for_available_slot state
        wait_for_state(pid, :wait_for_available_slot)
      end
    end
  end

  describe "Lazy.Executor marks campaign as successful" do
    setup %{tenant: tenant} do
      target_count = Enum.random(10..20)
      # 20 < x <= 70
      max_failure_percentage = 20 + :rand.uniform() * 50

      # Create a release with a specific version
      release_version = "2.1.0"
      release = release_fixture(version: release_version, system_models: 1, tenant: tenant)

      # Also define an higher version to test downgrade
      higher_release_version = "2.2.0"

      deployment_campaign =
        deployment_campaign_with_targets_fixture(target_count,
          release_id: release.id,
          deployment_mechanism: [
            max_in_progress_deployments: target_count,
            max_failure_percentage: max_failure_percentage
          ],
          tenant: tenant.tenant_id
        )

      %{pid: pid, ref: ref} =
        start_and_monitor_executor!(deployment_campaign, start_execution: false)

      ctx = [
        release: release,
        executor_pid: pid,
        higher_release_version: higher_release_version,
        max_failure_percentage: max_failure_percentage,
        monitor_ref: ref,
        target_count: target_count,
        deployment_campaign_id: deployment_campaign.id
      ]

      {:ok, ctx}
    end

    test "if all targets are successful", ctx do
      %{
        executor_pid: pid,
        monitor_ref: ref,
        deployment_campaign_id: deployment_campaign_id,
        tenant: tenant
      } = ctx

      start_execution(pid)

      # Wait for the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion)

      mark_all_pending_deployments_with_state(tenant, deployment_campaign_id, :stopped)

      assert_normal_exit(pid, ref)
      assert_deployment_campaign_outcome(tenant, deployment_campaign_id, :success)
    end

    test "if all targets already have the release version it's being rolled out", ctx do
      %{
        release: release,
        executor_pid: pid,
        monitor_ref: ref,
        deployment_campaign_id: deployment_campaign_id,
        tenant: tenant
      } = ctx

      # tenant realm device release
      DeploymentCampaign
      |> Ash.get!(deployment_campaign_id,
        tenant: tenant,
        load: [deployment_targets: [:device]]
      )
      |> Map.get(:deployment_targets, [])
      |> Enum.map(fn target -> fake_deploy(target.device, release, tenant) end)

      start_execution(pid)

      assert_normal_exit(pid, ref)
      assert_deployment_campaign_outcome(tenant, deployment_campaign_id, :success)
    end

    test "if just less than max_failure_percentage targets fail", ctx do
      %{
        executor_pid: pid,
        max_failure_percentage: max_failure_percentage,
        monitor_ref: ref,
        target_count: target_count,
        deployment_campaign_id: deployment_campaign_id,
        tenant: tenant
      } = ctx

      start_execution(pid)

      # Wait for the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion)

      deployment_ids =
        tenant.tenant_id
        |> Core.list_in_progress_targets(deployment_campaign_id)
        |> Enum.map(& &1.deployment_id)

      failing_target_count = max_failed_targets_for_success(target_count, max_failure_percentage)

      {failing_deployment_ids, successful_deployment_ids} =
        Enum.split(deployment_ids, failing_target_count)

      Enum.each(failing_deployment_ids, &update_deployment_state!(tenant, &1, :error))
      Enum.each(successful_deployment_ids, &update_deployment_state!(tenant, &1, :stopped))
      assert_normal_exit(pid, ref, 6000)
      assert_deployment_campaign_outcome(tenant, deployment_campaign_id, :success)
    end
  end

  describe "Lazy.Executor marks campaign as failed if max_failure_percentage is exceeded" do
    setup %{tenant: tenant} do
      target_count = Enum.random(10..20)
      # 20 < x <= 70
      max_failure_percentage = 20 + :rand.uniform() * 50

      # The minimum number of targets that have to fail to trigger a failure
      failing_target_count = min_failed_targets_for_failure(target_count, max_failure_percentage)

      # Create a release with a specific version and starting_version_requirement
      release_version = "2.1.0"

      release =
        release_fixture(
          version: release_version,
          system_models: 1,
          tenant: tenant
        )

      deployment_campaign =
        deployment_campaign_with_targets_fixture(target_count,
          release_id: release.id,
          deployment_mechanism: [
            max_in_progress_deployments: target_count,
            max_failure_percentage: max_failure_percentage
          ],
          tenant: tenant
        )

      %{pid: pid, ref: ref} =
        start_and_monitor_executor!(deployment_campaign, start_execution: false)

      ctx = [
        executor_pid: pid,
        failing_target_count: failing_target_count,
        monitor_ref: ref,
        deployment_campaign_id: deployment_campaign.id
      ]

      {:ok, ctx}
    end

    test "by failed Deployments", ctx do
      %{
        executor_pid: pid,
        failing_target_count: failing_target_count,
        monitor_ref: ref,
        deployment_campaign_id: deployment_campaign_id,
        tenant: tenant
      } = ctx

      # Start the execution
      start_execution(pid)

      # Wait for the Executor to arrive at :wait_for_campaign_completion
      wait_for_state(pid, :wait_for_campaign_completion)

      {failing_targets, remaining_targets} =
        tenant.tenant_id
        |> Core.list_in_progress_targets(deployment_campaign_id)
        |> Enum.split(failing_target_count)

      # Produce failing_target_count failures
      Enum.each(failing_targets, fn target ->
        update_deployment_state!(tenant, target.deployment_id, :error)
      end)

      # Now the Executor should arrive at :campaign_failure, but not terminate yet
      wait_for_state(pid, :campaign_failure)

      # Make the remaining targets reach a final state, some with success, some with failure
      # The random count guarantees that we have at least one success and one failure
      remaining_failing_count = Enum.random(1..(length(remaining_targets) - 1))

      {remaining_failing_targets, remaining_successful_targets} =
        Enum.split(remaining_targets, remaining_failing_count)

      Enum.each(remaining_successful_targets, fn target ->
        update_deployment_state!(tenant, target.deployment_id, :stopped)
      end)

      Enum.each(remaining_failing_targets, fn target ->
        update_deployment_state!(tenant, target.deployment_id, :error)
      end)

      # Now the Executor should terminate
      assert_normal_exit(pid, ref)
      assert_deployment_campaign_outcome(tenant, deployment_campaign_id, :failure)
    end

    test "by targets failing during the initial rollout with a non-temporary API failure", ctx do
      %{
        executor_pid: pid,
        failing_target_count: failing_target_count,
        monitor_ref: ref,
        deployment_campaign_id: deployment_campaign_id,
        tenant: tenant
      } = ctx

      # Expect failing_target_count calls to the mock and return a non-temporary error
      expect(
        CreateDeploymentRequestMock,
        :send_create_deployment_request,
        failing_target_count,
        fn _client, _device_id, _data ->
          status = Enum.random(400..499)
          {:error, %Astarte.Client.APIError{status: status, response: "F"}}
        end
      )

      # Start the execution
      start_execution(pid)

      assert_normal_exit(pid, ref)
      assert_deployment_campaign_outcome(tenant, deployment_campaign_id, :failure)
    end
  end

  defp fake_deploy(device, release, tenant) do
    deployment_fixture(
      tenant: tenant,
      device_id: device.id,
      release_id: release.id
    )
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
    CreateDeploymentRequestMock
  ]

  defp start_and_monitor_executor!(deployment_campaign, opts \\ []) do
    # We don't start the execution so we can monitor it before it completes
    pid = start_executor!(deployment_campaign, start_execution: false)
    ref = Process.monitor(pid)
    # After we monitor it, we can (maybe) manually start it
    maybe_start_execution(pid, opts)

    %{pid: pid, ref: ref}
  end

  defp start_executor!(deployment_campaign, opts \\ []) do
    args = executor_args(deployment_campaign)

    {Executor, args}
    |> start_supervised!()
    |> allow_test_resources()
    |> maybe_start_execution(opts)
  end

  defp executor_args(deployment_campaign) do
    [
      tenant_id: deployment_campaign.tenant_id,
      campaign_id: deployment_campaign.id,
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

  defp expect_deployment_requests_and_send_sync(count \\ 1) do
    # Asserts that count Deploy Requests where sent and sends a sync message for
    # each of them Returns the ref contained in the sync message
    parent = self()
    ref = make_ref()

    # Expect count calls to the mock
    expect(CreateDeploymentRequestMock, :send_create_deployment_request, count, fn _client, _device_id, _data ->
      # Send the sync
      send_sync(parent, ref)
      :ok
    end)

    ref
  end

  defp update_deployment_state!(tenant, deployment_id, state) do
    assert {:ok, deployment} =
             deployment_id
             |> Containers.fetch_deployment!(tenant: tenant)
             |> Containers.set_deployment_state!(%{state: state}, tenant: tenant)
             |> Containers.deployment_update_resources_state(tenant: tenant)

    deployment
  end

  defp deployment_device_online_for_targets(targets, online) do
    targets
    |> Ash.load!(:device)
    |> Enum.each(fn target ->
      Ash.update!(target.device, %{online: online}, action: :from_device_status)
    end)
  end

  defp mark_all_pending_deployments_with_state(tenant, deployment_campaign_id, state) do
    tenant.tenant_id
    |> Core.list_in_progress_targets(deployment_campaign_id)
    |> Enum.each(fn target ->
      update_deployment_state!(tenant, target.deployment_id, state)
    end)
  end

  defp assert_deployment_campaign_outcome(tenant, id, outcome) do
    deployment_campaign = Core.get_deployment_campaign!(tenant.tenant_id, id)
    assert deployment_campaign.status == :finished
    assert deployment_campaign.outcome == outcome
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
