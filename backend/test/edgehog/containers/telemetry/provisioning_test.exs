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

defmodule Edgehog.Containers.Telemetry.ProvisioningTest do
  @moduledoc """
  Tests for the provisioning telemetry events.
  """

  use Edgehog.DataCase, async: false

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures
  import Edgehog.TelemetryCapture

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Containers.Deployment.Provisioner
  alias Edgehog.Containers.Telemetry

  @moduletag :telemetry

  describe "Provisioning telemetry" do
    test "emits a start and successful stop event when the resource is already ready" do
      Edgehog.TelemetryCapture.start_capture([
        Telemetry.provisioning_start_event(),
        Telemetry.provisioning_stop_event()
      ])

      %{tenant: tenant, deployment: deployment} = deployment_context(ready: true)

      provisioner =
        case Provisioner.start(
               tenant: tenant,
               resource: deployment,
               mode: :manual
             ) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      Sandbox.allow(Edgehog.Repo, self(), provisioner)
      ref = Process.monitor(provisioner)

      {measurements, metadata} = assert_receive_event(Telemetry.provisioning_start_event())

      assert measurements.count == 1
      assert metadata.resource_type == "deployment"
      assert metadata.resource_id == deployment.id
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000

      {measurements, metadata} = assert_receive_event(Telemetry.provisioning_stop_event())

      assert measurements.count == 1
      assert measurements.retries == 0
      assert is_integer(measurements.duration)
      assert measurements.duration >= 0
      assert metadata.duration_unit == :native
      assert metadata.result == :ok
      assert metadata.reason == :already_ready
      assert metadata.resource_type == "deployment"
      assert metadata.resource_id == deployment.id
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id
    end

    test "emits a failed stop event when the device is offline at startup" do
      Edgehog.TelemetryCapture.start_capture([
        Telemetry.provisioning_start_event(),
        Telemetry.provisioning_stop_event()
      ])

      %{tenant: tenant, deployment: deployment} =
        deployment_context(ready: true, device_offline: true)

      provisioner =
        case Provisioner.start(
               tenant: tenant,
               resource: deployment,
               mode: :manual
             ) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      {_measurements, metadata} = assert_receive_event(Telemetry.provisioning_start_event())

      assert metadata.resource_type == "deployment"
      assert metadata.resource_id == deployment.id
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id

      # The device is offline at startup, so the provisioner gives up immediately
      # and the stop event is emitted
      {measurements, metadata} = assert_receive_event(Telemetry.provisioning_stop_event())

      assert measurements.count == 1
      assert measurements.retries == 0
      assert is_integer(measurements.duration)
      assert measurements.duration >= 0
      assert metadata.duration_unit == :native
      assert metadata.result == :error
      assert metadata.reason == :device_offline
      assert metadata.resource_type == "deployment"
      assert metadata.resource_id == deployment.id
      assert metadata.deployment_id == deployment.id
      assert metadata.device_id == deployment.device_id
    end
  end

  defp deployment_context(opts) do
    ready? = Keyword.get(opts, :ready, false)
    device_offline? = Keyword.get(opts, :device_offline, false)

    tenant = tenant_fixture()
    deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

    deployment =
      if ready? do
        make_deployment_ready!(deployment, tenant)
      else
        deployment
      end

    deployment =
      if device_offline? do
        mark_device_offline!(deployment, tenant)
      else
        mark_device_online!(deployment, tenant)
      end

    %{tenant: tenant, deployment: deployment}
  end

  defp mark_device_online!(deployment, tenant) do
    timestamp = now()

    opts = %{
      online: true,
      last_connection: timestamp,
      last_disconnection: timestamp
    }

    deployment
    |> Map.get(:device)
    |> Ash.Changeset.for_update(:from_device_status, opts)
    |> Ash.update!(tenant: tenant)
    |> then(&Map.put(deployment, :device, &1))
  end

  defp mark_device_offline!(deployment, tenant) do
    timestamp = now()

    opts = %{
      online: false,
      last_connection: timestamp,
      last_disconnection: timestamp
    }

    deployment
    |> Map.get(:device)
    |> Ash.Changeset.for_update(:from_device_status, opts)
    |> Ash.update!(tenant: tenant)
    |> then(&Map.put(deployment, :device, &1))
  end

  defp now, do: DateTime.now!("Etc/UTC")
end
