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

defmodule Edgehog.Campaigns.Executors.FileDownloadExecutorTest do
  use Edgehog.DataCase, async: true

  import Edgehog.CampaignsFixtures
  import Edgehog.TenantsFixtures

  alias Astarte.Client.APIError
  alias Ecto.Adapters.SQL
  alias Edgehog.Astarte.Device.DeviceStatusMock
  alias Edgehog.Astarte.Device.FileDownloadRequest.RequestData
  alias Edgehog.Astarte.Device.FileDownloadRequestMock
  alias Edgehog.Astarte.Device.FileTransferCapabilities
  alias Edgehog.Astarte.Device.FileTransferCapabilitiesMock
  alias Edgehog.Campaigns
  alias Edgehog.Campaigns.Campaign
  alias Edgehog.Campaigns.CampaignMechanism.Core, as: MechanismCore
  alias Edgehog.Campaigns.CampaignMechanism.FileDownload
  alias Edgehog.Campaigns.CampaignMechanism.FileDownload.Executor
  alias Edgehog.Files
  alias Edgehog.StorageMock

  setup do
    stub(DeviceStatusMock, :get, fn _client, _device_id ->
      {:error, :not_found}
    end)

    stub(FileDownloadRequestMock, :request_download, fn _client, _device_id, _request_data ->
      :ok
    end)

    stub(FileTransferCapabilitiesMock, :get, fn _client, _device_id ->
      {:ok,
       %FileTransferCapabilities{
         encodings: [],
         unix_permissions: false,
         targets: [:filesystem]
       }}
    end)

    stub(StorageMock, :read_presigned_url, fn path ->
      {:ok, %{get_url: "http://example.test/#{path}"}}
    end)

    %{tenant: tenant_fixture()}
  end

  describe "Executor immediately terminates" do
    test "when a file download campaign has no targets", %{tenant: tenant} do
      campaign = campaign_fixture(tenant: tenant, mechanism_type: :file_download)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(campaign)

      assert_normal_exit(pid, ref)
    end

    test "when file download campaign is already marked as failed", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :file_download)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [])

      mechanism = campaign.campaign_mechanism.value
      [target] = campaign.campaign_targets
      _ = MechanismCore.mark_target_as_failed!(mechanism, target)
      _ = MechanismCore.mark_campaign_as_failed!(mechanism, campaign)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(campaign)

      assert_normal_exit(pid, ref)
    end

    test "when file download campaign is already marked as successful", %{tenant: tenant} do
      campaign =
        1
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :file_download)
        |> Ash.load!(campaign_targets: [], campaign_mechanism: [])

      mechanism = campaign.campaign_mechanism.value

      [target] = campaign.campaign_targets
      _ = MechanismCore.mark_target_as_successful!(mechanism, target)
      _ = MechanismCore.mark_campaign_as_successful!(mechanism, campaign)

      %{pid: pid, ref: ref} = start_and_monitor_executor!(campaign)

      assert_normal_exit(pid, ref)
    end
  end

  describe "Executor resumes :in_progress file download campaign" do
    test "when it already has `max_in_progress_operations` pending requests", %{tenant: tenant} do
      target_count = Enum.random(10..20)
      max_in_progress_operations = Enum.random(2..5)

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :file_download,
          campaign_mechanism: [max_in_progress_operations: max_in_progress_operations],
          tenant: tenant
        )

      pid = start_executor!(campaign)

      wait_for_state(pid, :wait_for_available_slot, 1000)

      stop_supervised(Executor)

      resumed_pid = start_executor!(campaign)

      _ = expect_file_download_requests_and_send_sync(0)

      wait_for_state(resumed_pid, :wait_for_available_slot)
    end

    test "when it is waiting for completion", %{tenant: tenant} do
      target_count = Enum.random(2..20)

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :file_download,
          campaign_mechanism: [max_in_progress_operations: target_count],
          tenant: tenant
        )

      pid = start_executor!(campaign)

      wait_for_state(pid, :wait_for_campaign_completion, 1000)

      stop_supervised(Executor)

      resumed_pid = start_executor!(campaign)

      _ = expect_file_download_requests_and_send_sync(0)

      wait_for_state(resumed_pid, :wait_for_campaign_completion)
    end
  end

  describe "Executor sends" do
    test "all target File Download Requests in parallel if there are enough available slots", %{
      tenant: tenant
    } do
      target_count = Enum.random(2..20)

      campaign =
        target_count
        |> campaign_with_targets_fixture(
          mechanism_type: :file_download,
          campaign_mechanism: [max_in_progress_operations: target_count],
          tenant: tenant
        )
        |> Ash.load!(campaign_targets: [device: [:device_id]])

      parent = self()
      ref = make_ref()
      target_device_ids = Enum.map(campaign.campaign_targets, & &1.device.device_id)

      expect(
        FileDownloadRequestMock,
        :request_download,
        target_count,
        fn _client, device_id, _request_data ->
          send_sync(parent, {ref, device_id})
          :ok
        end
      )

      pid = start_executor!(campaign)

      target_device_ids
      |> Enum.map(&{ref, &1})
      |> wait_for_sync!()

      wait_for_state(pid, :wait_for_campaign_completion)
    end

    test "at most `max_in_progress_operations` File Download Requests", %{tenant: tenant} do
      target_count = Enum.random(10..20)
      max_in_progress_operations = Enum.random(2..5)

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :file_download,
          campaign_mechanism: [max_in_progress_operations: max_in_progress_operations],
          tenant: tenant
        )

      ref = expect_file_download_requests_and_send_sync(max_in_progress_operations)

      pid = start_executor!(campaign)

      ref
      |> repeat(max_in_progress_operations)
      |> wait_for_sync!()

      wait_for_state(pid, :wait_for_available_slot)
    end

    test "File Download Requests only to online targets", %{tenant: tenant} do
      target_count = Enum.random(10..20)
      offline_count = Enum.random(1..target_count)
      online_count = target_count - offline_count

      campaign =
        target_count
        |> campaign_with_targets_fixture(tenant: tenant, mechanism_type: :file_download)
        |> Ash.load!(:campaign_targets)

      {offline_targets, online_targets} =
        Enum.split(campaign.campaign_targets, offline_count)

      update_device_online_for_targets(online_targets, true)
      update_device_online_for_targets(offline_targets, false)

      ref = expect_file_download_requests_and_send_sync(online_count)

      pid = start_executor!(campaign)

      ref
      |> repeat(online_count)
      |> wait_for_sync!()

      wait_for_state(pid, :wait_for_target)
    end
  end

  describe "Executor receiving a FileDownloadRequest update" do
    setup %{tenant: tenant} do
      target_count = 10
      max_requests = 5

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :file_download,
          campaign_mechanism: [max_in_progress_operations: max_requests],
          tenant: tenant
        )

      parent = self()

      expect(
        FileDownloadRequestMock,
        :request_download,
        max_requests,
        fn _client, _device_id, %RequestData{id: file_download_request_id} ->
          send(parent, {:file_download_request_target, file_download_request_id})
          :ok
        end
      )

      pid = start_executor!(campaign)

      wait_for_state(pid, :wait_for_available_slot)

      verify!()

      file_download_request_id =
        receive do
          {:file_download_request_target, file_download_request_id} ->
            file_download_request_id
        after
          1000 -> flunk()
        end

      flush_messages()

      {:ok, executor_pid: pid, file_download_request_id: file_download_request_id}
    end

    for status <- [:completed, :failed] do
      test "frees up slot if FileDownloadRequest status is #{status}", ctx do
        %{
          executor_pid: pid,
          file_download_request_id: file_download_request_id,
          tenant: tenant
        } = ctx

        ref = expect_file_download_requests_and_send_sync()

        update_file_download_request_status!(tenant, file_download_request_id, unquote(status))

        wait_for_sync!(ref)

        wait_for_state(pid, :wait_for_available_slot)
      end
    end

    for status <- [:sent, :in_progress] do
      test "doesn't free up slots if FileDownloadRequest status is #{status}", ctx do
        %{
          executor_pid: pid,
          file_download_request_id: file_download_request_id,
          tenant: tenant
        } = ctx

        expect(
          FileDownloadRequestMock,
          :request_download,
          0,
          fn _client, _device_id, _request_data ->
            :ok
          end
        )

        update_file_download_request_status!(tenant, file_download_request_id, unquote(status))

        wait_for_state(pid, :wait_for_available_slot)
      end
    end
  end

  describe "Executor marks file download campaign as successful" do
    setup %{tenant: tenant} do
      target_count = 5
      max_failure_percentage = 20 + :rand.uniform() * 50

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :file_download,
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

      wait_for_state(pid, :wait_for_campaign_completion)

      mark_all_pending_file_download_requests_with_status(tenant, campaign_id, :completed)

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

      wait_for_state(pid, :wait_for_campaign_completion)

      file_download_request_ids =
        %FileDownload{}
        |> MechanismCore.list_in_progress_targets(tenant.tenant_id, campaign_id)
        |> Enum.map(& &1.file_download_request_id)

      failing_target_count = max_failed_targets_for_success(target_count, max_failure_percentage)

      {failing_file_download_request_ids, successful_file_download_request_ids} =
        Enum.split(file_download_request_ids, failing_target_count)

      Enum.each(failing_file_download_request_ids, fn id ->
        update_file_download_request_status!(tenant, id, :failed)
      end)

      Enum.each(successful_file_download_request_ids, fn id ->
        update_file_download_request_status!(tenant, id, :completed)
      end)

      assert_normal_exit(pid, ref)
      assert_campaign_outcome(tenant, campaign_id, :success)
    end
  end

  describe "Executor marks file download campaign as failed if `max_failure_percentage` is exceeded" do
    setup %{tenant: tenant} do
      target_count = Enum.random(10..20)
      max_failure_percentage = 20 + :rand.uniform() * 50

      failing_target_count = min_failed_targets_for_failure(target_count, max_failure_percentage)

      campaign =
        campaign_with_targets_fixture(target_count,
          mechanism_type: :file_download,
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

    test "by failed File Download Requests", ctx do
      %{
        executor_pid: pid,
        failing_target_count: failing_target_count,
        monitor_ref: ref,
        campaign_id: campaign_id,
        tenant: tenant
      } = ctx

      start_execution(pid)

      wait_for_state(pid, :wait_for_campaign_completion)

      {failing_targets, remaining_targets} =
        %FileDownload{}
        |> MechanismCore.list_in_progress_targets(tenant.tenant_id, campaign_id)
        |> Enum.split(failing_target_count)

      Enum.each(failing_targets, fn target ->
        update_file_download_request_status!(tenant, target.file_download_request_id, :failed)
      end)

      wait_for_state(pid, :campaign_failure)

      remaining_failing_count = Enum.random(1..(length(remaining_targets) - 1))

      {remaining_failing_targets, remaining_successful_targets} =
        Enum.split(remaining_targets, remaining_failing_count)

      Enum.each(remaining_successful_targets, fn target ->
        update_file_download_request_status!(tenant, target.file_download_request_id, :completed)
      end)

      Enum.each(remaining_failing_targets, fn target ->
        update_file_download_request_status!(tenant, target.file_download_request_id, :failed)
      end)

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

      expect(
        FileDownloadRequestMock,
        :request_download,
        failing_target_count,
        fn _client, _device_id, _request_data ->
          status = Enum.random(400..499)
          {:error, %APIError{status: status, response: "F"}}
        end
      )

      start_execution(pid)

      assert_normal_exit(pid, ref, 3000)
      assert_campaign_outcome(tenant, campaign_id, :failure)
    end
  end

  describe "pause and resume file download executor" do
    test "pause suppresses new file download requests and resume restarts rollout", %{
      tenant: tenant
    } do
      max_requests = 3

      campaign =
        campaign_with_targets_fixture(8,
          mechanism_type: :file_download,
          campaign_mechanism: [max_in_progress_operations: max_requests],
          tenant: tenant
        )

      init_ref = expect_file_download_requests_and_send_sync(max_requests)

      pid = start_executor!(campaign)

      wait_for_sync!(repeat(init_ref, max_requests))

      wait_for_state(pid, :wait_for_available_slot)

      expect(
        FileDownloadRequestMock,
        :request_download,
        0,
        fn _client, _device_id, _request_data ->
          :ok
        end
      )

      ref = Process.monitor(pid)

      campaign = Ash.get!(Campaign, campaign.id, tenant: tenant)

      {:ok, _paused_campaign} = Campaigns.pause_campaign(campaign)

      wait_for_state(pid, :wait_for_campaign_paused)

      %{tenant_id: tenant_id, id: campaign_id} = campaign

      %FileDownload{}
      |> MechanismCore.list_in_progress_targets(tenant_id, campaign_id)
      |> Enum.each(fn target ->
        update_file_download_request_status!(tenant, target.file_download_request_id, :completed)
      end)

      assert_normal_exit(pid, ref)

      resume_ref = expect_file_download_requests_and_send_sync(max_requests)

      paused_campaign = Ash.get!(Campaign, campaign.id, tenant: tenant)

      {:ok, _resumed_campaign} = Campaigns.resume_campaign(paused_campaign)

      executor_id = {tenant_id, campaign_id, :file_download}
      [{new_pid, _}] = Registry.lookup(Edgehog.Campaigns.ExecutorRegistry, executor_id)

      allow_test_resources(new_pid)

      start_execution(new_pid)

      wait_for_sync!(repeat(resume_ref, max_requests))

      wait_for_state(new_pid, :wait_for_available_slot)
    end

    test "campaign can complete while paused", %{tenant: tenant} do
      campaign =
        campaign_with_targets_fixture(4,
          mechanism_type: :file_download,
          campaign_mechanism: [max_in_progress_operations: 4],
          tenant: tenant
        )

      pid = start_executor!(campaign)

      wait_for_state(pid, :wait_for_campaign_completion)

      ref = Process.monitor(pid)

      campaign = Ash.get!(Campaign, campaign.id, tenant: tenant)

      {:ok, _paused_campaign} = Campaigns.pause_campaign(campaign)

      wait_for_state(pid, :wait_for_campaign_paused)

      %FileDownload{}
      |> MechanismCore.list_in_progress_targets(campaign.tenant_id, campaign.id)
      |> Enum.each(fn target ->
        update_file_download_request_status!(tenant, target.file_download_request_id, :completed)
      end)

      assert_normal_exit(pid, ref)
    end
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
    deadline_ms = System.monotonic_time(:millisecond) + timeout

    loop_until_state!(executor_pid, state, deadline_ms)
  end

  defp loop_until_state!(executor_pid, state, deadline_ms) do
    remaining_time = deadline_ms - System.monotonic_time(:millisecond)

    if remaining_time <= 0 do
      {actual_state, _data} = :sys.get_state(executor_pid)
      flunk("State #{state} not reached, last state: #{actual_state}")
    else
      case :sys.get_state(executor_pid) do
        {^state, _data} ->
          :ok

        _other ->
          Process.sleep(100)
          loop_until_state!(executor_pid, state, deadline_ms)
      end
    end
  end

  @executor_allowed_mocks [
    DeviceStatusMock,
    FileTransferCapabilitiesMock,
    FileDownloadRequestMock,
    StorageMock
  ]

  defp start_and_monitor_executor!(campaign, opts \\ []) do
    pid = start_executor!(campaign, start_execution: false)
    ref = Process.monitor(pid)
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
      wait_for_start_execution: true
    ]
  end

  defp allow_test_resources(pid) do
    Enum.each(@executor_allowed_mocks, &Mox.allow(&1, self(), pid))

    SQL.Sandbox.allow(Repo, self(), pid)

    pid
  end

  defp maybe_start_execution(pid, opts) do
    if Keyword.get(opts, :start_execution, true) do
      start_execution(pid)
    else
      pid
    end
  end

  def start_execution(pid) do
    send(pid, :start_execution)

    pid
  end

  defp expect_file_download_requests_and_send_sync(count \\ 1) do
    parent = self()
    ref = make_ref()

    expect(FileDownloadRequestMock, :request_download, count, fn _client,
                                                                 _device_id,
                                                                 _request_data ->
      send_sync(parent, ref)
      :ok
    end)

    ref
  end

  defp update_file_download_request_status!(tenant, file_download_request_id, status) do
    response =
      case status do
        :completed -> %{status: :completed, response_code: 0, response_message: "Success"}
        :failed -> %{status: :failed, response_code: 1, response_message: "Failed"}
        _ -> %{status: status, response_code: 0, response_message: nil}
      end

    assert {:ok, file_download_request} =
             file_download_request_id
             |> Files.fetch_file_download_request!(tenant: tenant)
             |> Files.set_response(response, tenant: tenant)

    file_download_request
  end

  defp update_device_online_for_targets(targets, online) do
    targets
    |> Ash.load!(file_download_request: [:status], device: [realm: [:cluster]])
    |> Enum.each(fn target ->
      Ash.update!(target.device, %{online: online}, action: :from_device_status)
    end)
  end

  defp mark_all_pending_file_download_requests_with_status(tenant, campaign_id, status) do
    %FileDownload{}
    |> MechanismCore.list_in_progress_targets(tenant.tenant_id, campaign_id)
    |> Enum.each(fn target ->
      update_file_download_request_status!(tenant, target.file_download_request_id, status)
    end)
  end

  defp assert_campaign_outcome(tenant, id, outcome) do
    campaign = MechanismCore.get_campaign!(%FileDownload{}, tenant.tenant_id, id)
    assert campaign.status == :finished
    assert campaign.outcome == outcome
  end

  defp max_failed_targets_for_success(target_count, max_failure_percentage) do
    floor(target_count * max_failure_percentage / 100)
  end

  defp min_failed_targets_for_failure(target_count, max_failure_percentage) do
    1 + max_failed_targets_for_success(target_count, max_failure_percentage)
  end

  defp repeat(value, n) do
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
