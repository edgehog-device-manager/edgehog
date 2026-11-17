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

defmodule Edgehog.Devices.PromExPluginTest do
  use Edgehog.DataCase, async: false

  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.ForwarderSession
  alias Edgehog.Devices.PromExPlugin
  alias Edgehog.Forwarder.Telemetry

  test "exports connected device counts and sample timestamps per tenant" do
    tenant_a = tenant_fixture()
    tenant_b = tenant_fixture()
    tenant_c = tenant_fixture()

    connected = device_fixture(tenant: tenant_a, online: true)
    device_fixture(tenant: tenant_a, online: false)
    device_fixture(tenant: tenant_b, online: true)
    device_fixture(tenant: tenant_b, online: true)

    [polling, _] = PromExPlugin.polling_metrics([])
    assert polling.poll_rate == 300_000
    assert Edgehog.Devices.PromExPlugin in Edgehog.PromEx.plugins()

    start_supervised!(
      {TelemetryMetricsPrometheus.Core,
       name: :fleet_metrics_test,
       metrics: polling.metrics,
       require_seconds: false,
       start_async: false}
    )

    before_sample = System.system_time(:second)
    PromExPlugin.emit_connected_devices_count()
    after_sample = System.system_time(:second)
    metrics = TelemetryMetricsPrometheus.Core.scrape(:fleet_metrics_test)

    for {tenant, count, total} <- [{tenant_a, 1, 2}, {tenant_b, 2, 2}, {tenant_c, 0, 0}] do
      labels = ~s(tenant_slug="#{tenant.slug}")

      assert ~s(edgehog_fleet_connected_devices{#{labels}} #{count}) in String.split(
               metrics,
               "\n"
             )

      assert ~s(edgehog_fleet_total_devices{#{labels}} #{total}) in String.split(metrics, "\n")

      timestamp_pattern =
        ~r/^edgehog_fleet_connected_devices_sample_timestamp_seconds\{#{Regex.escape(labels)}\} (\d+)$/m

      assert [_, timestamp] = Regex.run(timestamp_pattern, metrics)
      assert String.to_integer(timestamp) in before_sample..after_sample
    end

    connected
    |> Ash.Changeset.for_update(:from_device_status, %{online: false}, tenant: tenant_a)
    |> Ash.update!()

    PromExPlugin.emit_connected_devices_count()
    metrics = TelemetryMetricsPrometheus.Core.scrape(:fleet_metrics_test)
    labels = ~s(tenant_slug="#{tenant_a.slug}")
    assert ~s(edgehog_fleet_connected_devices{#{labels}} 0) in String.split(metrics, "\n")
  end

  test "exports active forwarder sessions per tenant" do
    tenant_a = tenant_fixture()
    tenant_b = tenant_fixture()

    device_a = device_fixture(tenant: tenant_a, online: true)
    device_fixture(tenant: tenant_a, online: false)
    device_fixture(tenant: tenant_b, online: true)

    device_id = device_a.device_id

    stub(ForwarderSession, :list_sessions, fn _client, id ->
      sessions =
        if id == device_id do
          [:connected, :connecting, :connected]
        else
          [:connecting]
        end

      {:ok,
       Enum.map(sessions, fn status ->
         %ForwarderSession{
           token: Ash.UUID.generate(),
           status: status,
           secure: false,
           forwarder_hostname: "localhost",
           forwarder_port: 4001
         }
       end)}
    end)

    [_, polling] = PromExPlugin.polling_metrics([])

    start_supervised!(
      {TelemetryMetricsPrometheus.Core,
       name: :fleet_forwarder_metrics_test,
       metrics: polling.metrics,
       require_seconds: false,
       start_async: false}
    )

    PromExPlugin.emit_active_forwarder_sessions_count()

    lines =
      :fleet_forwarder_metrics_test
      |> TelemetryMetricsPrometheus.Core.scrape()
      |> String.split("\n")

    assert ~s(edgehog_fleet_active_forwarder_sessions{tenant_slug="#{tenant_a.slug}"} 2) in lines
    assert ~s(edgehog_fleet_active_forwarder_sessions{tenant_slug="#{tenant_b.slug}"} 0) in lines
  end

  test "counts requested forwarder sessions per tenant" do
    tenant_a = tenant_fixture()
    tenant_b = tenant_fixture()

    [metrics] = PromExPlugin.event_metrics([])

    start_supervised!(
      {TelemetryMetricsPrometheus.Core,
       name: :fleet_forwarder_requests_test,
       metrics: metrics.metrics,
       require_seconds: false,
       start_async: false}
    )

    Telemetry.session_requested(tenant_a)
    Telemetry.session_requested(tenant_a)
    Telemetry.session_requested(tenant_b)

    lines =
      :fleet_forwarder_requests_test
      |> TelemetryMetricsPrometheus.Core.scrape()
      |> String.split("\n")

    assert ~s(edgehog_fleet_forwarder_sessions_requested_total{tenant_slug="#{tenant_a.slug}"} 2) in lines

    assert ~s(edgehog_fleet_forwarder_sessions_requested_total{tenant_slug="#{tenant_b.slug}"} 1) in lines
  end
end
