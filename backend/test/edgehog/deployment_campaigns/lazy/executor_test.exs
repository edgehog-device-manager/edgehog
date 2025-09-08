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
  alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core
  alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Executor

  setup do
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

  @executor_allowed_mocks [
    Edgehog.Astarte.Device.DeviceStatusMock
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

  defp assert_normal_exit(pid, ref, timeout \\ 1000) do
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal},
                   timeout,
                   "Process did not terminate with reason :normal as expected"
  end
end
