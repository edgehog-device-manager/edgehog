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

defmodule EdgehogWeb.DevicesLive.Index do
  @moduledoc """
  LiveView for browsing, filtering, and monitoring a tenant's device fleet in
  real time.

  Composes `FleetStatsComponent` and a `Cinder.collection` table whose cells are
  independent `Phoenix.LiveComponent`s subscribed to granular Ash PubSub topics.
  """
  use EdgehogWeb, :live_view

  alias Edgehog.Devices.Device
  alias EdgehogWeb.DevicesLive.FleetStatsComponent
  alias EdgehogWeb.DevicesLive.LastSeenCellComponent
  alias EdgehogWeb.DevicesLive.NameCellComponent
  alias EdgehogWeb.DevicesLive.StatusCellComponent
  alias EdgehogWeb.DevicesLive.TagsCellComponent

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_tenant

    if connected?(socket) do
      EdgehogWeb.Endpoint.subscribe("devices:tenant:#{tenant.tenant_id}")
    end

    query =
      Device
      |> Ash.Query.for_read(:read, %{}, tenant: tenant, authorize?: false)
      |> Ash.Query.load([:system_model, :tags])

    {:ok,
     socket
     |> assign(:page_title, "Devices · #{tenant.name}")
     |> assign(:devices_query, query)}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:online:" <> id,
          payload: %Ash.Notifier.Notification{data: device}
        },
        socket
      ) do
    send_update(StatusCellComponent, id: "device-status-#{id}", device: device)
    send_update(FleetStatsComponent, id: "fleet-stats", tenant: socket.assigns.current_tenant)
    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:offline:" <> id,
          payload: %Ash.Notifier.Notification{data: device}
        },
        socket
      ) do
    send_update(StatusCellComponent, id: "device-status-#{id}", device: device)
    send_update(FleetStatsComponent, id: "fleet-stats", tenant: socket.assigns.current_tenant)
    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:name:" <> id,
          payload: %Ash.Notifier.Notification{data: device}
        },
        socket
      ) do
    send_update(NameCellComponent, id: "device-name-#{id}", device: device)
    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:connection:" <> id,
          payload: %Ash.Notifier.Notification{data: device}
        },
        socket
      ) do
    send_update(LastSeenCellComponent, id: "device-last-seen-#{id}", device: device)
    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:tags:" <> id,
          payload: %Ash.Notifier.Notification{data: device}
        },
        socket
      ) do
    send_update(TagsCellComponent,
      id: "device-tags-#{id}",
      device: device,
      tenant: socket.assigns.current_tenant
    )

    {:noreply, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "devices:tenant:" <> _tenant_id,
          payload: %Ash.Notifier.Notification{action: %{type: action_type}}
        },
        socket
      )
      when action_type in [:create, :destroy] do
    send_update(FleetStatsComponent, id: "fleet-stats", tenant: socket.assigns.current_tenant)
    {:noreply, Cinder.Refresh.refresh_table(socket, "devices-table")}
  end

  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-6 space-y-6">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div class="flex items-center gap-2">
            <h1 class="text-2xl font-bold tracking-tight text-base-content">
              Devices
            </h1>
            <span
              id="live-pubsub-indicator"
              class="badge badge-soft badge-success badge-sm gap-1.5 font-medium"
              title="Subscribed to live device telemetry updates"
            >
              <span class="status status-success animate-pulse"></span> Live
            </span>
          </div>
          <p class="text-sm text-base-content/60 mt-1">
            Real-time overview and connection status of devices provisioned in <span class="font-medium text-base-content/80">{@current_tenant.name}</span>.
          </p>
        </div>
      </div>

      <.live_component
        module={FleetStatsComponent}
        id="fleet-stats"
        tenant={@current_tenant}
      />

      <Cinder.collection
        id="devices-table"
        query={@devices_query}
        tenant={@current_tenant}
        page_size={[default: 15, options: [10, 15, 25, 50]]}
        search={false}
      >
        <:col :let={device} field="online" sort label="Status">
          <.live_component
            module={StatusCellComponent}
            id={"device-status-#{device.id}"}
            device={device}
          />
        </:col>

        <:col :let={device} field="name" sort search label="Device">
          <.live_component
            module={NameCellComponent}
            id={"device-name-#{device.id}"}
            device={device}
          />
        </:col>

        <:col :let={device} field="device_id" hidden label="Device ID">
          <span class="font-mono text-base-content/55 tabular-nums">
            {device.device_id}
          </span>
        </:col>

        <:col :let={device} field="serial_number" hidden label="System Model">
          <%= if device.system_model do %>
            {device.system_model.name}
          <% else %>
            <span class="text-xl font-mono text-base-content/55 tabular-nums"> - </span>
          <% end %>
        </:col>

        <:col :let={device} field="last_connection" sort label="Last Seen">
          <.live_component
            module={LastSeenCellComponent}
            id={"device-last-seen-#{device.id}"}
            device={device}
          />
        </:col>

        <:col :let={device} field="tags" label="Tags">
          <.live_component
            module={TagsCellComponent}
            id={"device-tags-#{device.id}"}
            device={device}
            tenant={@current_tenant}
          />
        </:col>
      </Cinder.collection>
    </div>
    """
  end
end
