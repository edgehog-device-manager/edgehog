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

defmodule EdgehogWeb.DevicesLive.FleetStatsComponent do
  @moduledoc """
  LiveComponent rendering reactive fleet summary metrics (Total, Online,
  Offline, and Availability ratio) for a tenant.
  """
  use EdgehogWeb, :live_component

  alias Edgehog.Devices.Device

  require Ash.Query

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    tenant = assigns.tenant
    stats = compute_stats(tenant)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(stats)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <section
      id={@id}
      aria-label="Fleet telemetry summary"
      class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4"
    >
      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Total Fleet
          </span>
          <.icon name="hero-cpu-chip" class="size-4 text-base-content/45" />
        </div>
        <p id="stat-total-devices" class="mt-2 text-2xl font-bold tabular-nums text-base-content">
          {@total_count}
        </p>
        <p class="mt-0.5 text-xs text-base-content/55">Provisioned endpoints</p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Online
          </span>
          <span class="status status-success"></span>
        </div>
        <p id="stat-online-devices" class="mt-2 text-2xl font-bold tabular-nums text-success">
          {@online_count}
        </p>
        <p class="mt-0.5 text-xs text-base-content/55">Active Astarte session</p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Offline
          </span>
          <span class="status"></span>
        </div>
        <p id="stat-offline-devices" class="mt-2 text-2xl font-bold tabular-nums text-base-content">
          {@offline_count}
        </p>
        <p class="mt-0.5 text-xs text-base-content/55">Disconnected or standby</p>
      </div>

      <div class="card card-border bg-base-100 p-4 shadow-xs">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
            Availability
          </span>
          <.icon name="hero-signal" class="size-4 text-primary" />
        </div>
        <div class="mt-2 flex items-baseline gap-2">
          <p id="stat-availability-pct" class="text-2xl font-bold tabular-nums text-base-content">
            {@availability_pct}%
          </p>
        </div>
        <progress
          class="progress progress-primary mt-2 w-full"
          value={@availability_pct}
          max="100"
        />
      </div>
    </section>
    """
  end

  defp compute_stats(tenant) do
    total_count = Ash.count!(Device, tenant: tenant, authorize?: false)

    online_count =
      Device
      |> Ash.Query.filter(online == true)
      |> Ash.count!(tenant: tenant, authorize?: false)

    offline_count = max(total_count - online_count, 0)

    availability_pct =
      if total_count > 0 do
        round(online_count / total_count * 100)
      else
        0
      end

    %{
      total_count: total_count,
      online_count: online_count,
      offline_count: offline_count,
      availability_pct: availability_pct
    }
  end
end
