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

defmodule Edgehog.Devices.PromExPlugin do
  @moduledoc """
  PromEx plugin for tenant fleet metrics.
  """

  use PromEx.Plugin

  alias Edgehog.Devices.Device
  alias Edgehog.Forwarder.Telemetry, as: ForwarderTelemetry
  alias Edgehog.Tenants.Tenant

  require Ash.Query
  require Logger

  @connected_devices_event [:edgehog, :fleet, :connected_devices]
  @active_forwarder_sessions_event [:edgehog, :fleet, :active_forwarder_sessions]
  @poll_rate_ms 300_000

  @impl PromEx.Plugin
  def event_metrics(_opts) do
    [
      Event.build(
        :fleet_forwarder_session_event_metrics,
        [
          counter([:edgehog, :fleet, :forwarder_sessions, :requested, :total],
            event_name: ForwarderTelemetry.session_requested_event(),
            measurement: :count,
            tags: [:tenant_slug],
            description: "Number of forwarder sessions requested to devices of a tenant."
          )
        ]
      )
    ]
  end

  @impl PromEx.Plugin
  def polling_metrics(_opts) do
    [
      Polling.build(
        :fleet_connected_devices_polling_metrics,
        @poll_rate_ms,
        {__MODULE__, :emit_connected_devices_count, []},
        [
          last_value(@connected_devices_event,
            event_name: @connected_devices_event,
            measurement: :count,
            tags: [:tenant_slug],
            description: "Number of connected devices managed by a tenant."
          ),
          last_value([:edgehog, :fleet, :total_devices],
            event_name: @connected_devices_event,
            measurement: :total_count,
            tags: [:tenant_slug],
            description: "Total number of devices managed by a tenant."
          ),
          last_value([:edgehog, :fleet, :connected_devices, :sample_timestamp_seconds],
            event_name: @connected_devices_event,
            measurement: :sample_timestamp_seconds,
            tags: [:tenant_slug],
            description: "Unix timestamp of the last successful device count."
          )
        ],
        detach_on_error: false
      ),
      Polling.build(
        :fleet_active_forwarder_sessions_polling_metrics,
        @poll_rate_ms,
        {__MODULE__, :emit_active_forwarder_sessions_count, []},
        [
          last_value(@active_forwarder_sessions_event,
            event_name: @active_forwarder_sessions_event,
            measurement: :count,
            tags: [:tenant_slug],
            description: "Number of connected forwarder sessions of a tenant."
          ),
          last_value([:edgehog, :fleet, :active_forwarder_sessions, :sample_timestamp_seconds],
            event_name: @active_forwarder_sessions_event,
            measurement: :sample_timestamp_seconds,
            tags: [:tenant_slug],
            description: "Unix timestamp of the last successful forwarder session count."
          )
        ],
        detach_on_error: false
      )
    ]
  end

  def count_connected_devices(tenant) do
    Device
    |> Ash.Query.filter(online: true)
    |> Ash.count(tenant: tenant)
  end

  def count_total_devices(tenant) do
    Ash.count(Device, tenant: tenant)
  end

  def emit_connected_devices_count do
    Tenant
    |> Ash.read!()
    |> Enum.each(fn tenant ->
      with {:ok, count} <- count_connected_devices(tenant),
           {:ok, total_count} <- count_total_devices(tenant) do
        :telemetry.execute(
          @connected_devices_event,
          %{
            count: count,
            total_count: total_count,
            sample_timestamp_seconds: System.system_time(:second)
          },
          %{tenant_slug: tenant.slug}
        )
      else
        {:error, error} ->
          Logger.error(
            "Failed to count devices for tenant #{tenant.tenant_id}: #{inspect(error)}"
          )
      end
    end)
  end

  # Sessions are only stored on Astarte, so one request per online device is needed.
  def count_active_forwarder_sessions(tenant) do
    query =
      Device
      |> Ash.Query.filter(online: true)
      |> Ash.Query.load(:forwarder_sessions)

    with {:ok, devices} <- Ash.read(query, tenant: tenant) do
      {:ok, count_connected_sessions(devices)}
    end
  end

  defp count_connected_sessions(devices) do
    devices
    |> Enum.flat_map(& &1.forwarder_sessions)
    |> Enum.count(&(&1.status == :connected))
  end

  def emit_active_forwarder_sessions_count do
    Tenant
    |> Ash.read!()
    |> Enum.each(fn tenant ->
      case count_active_forwarder_sessions(tenant) do
        {:ok, count} ->
          :telemetry.execute(
            @active_forwarder_sessions_event,
            %{count: count, sample_timestamp_seconds: System.system_time(:second)},
            %{tenant_slug: tenant.slug}
          )

        {:error, error} ->
          Logger.error(
            "Failed to count forwarder sessions for tenant #{tenant.tenant_id}: #{inspect(error)}"
          )
      end
    end)
  end
end
