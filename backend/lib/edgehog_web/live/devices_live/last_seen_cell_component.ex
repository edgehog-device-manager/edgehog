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

defmodule EdgehogWeb.DevicesLive.LastSeenCellComponent do
  @moduledoc """
  Reactive table cell LiveComponent displaying a device's last connection or
  disconnection activity timestamp.

  Subscribes to `"devices:connection:<id>"` so connection and disconnection
  events update the timestamp in place.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{device: device} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:last_connection, device.last_connection)
      |> assign(:last_disconnection, device.last_disconnection)
      |> ensure_subscribed(device.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <span id={@id} class="text-xs font-mono text-base-content/70 tabular-nums">
      {format_timestamp(latest_activity(@last_connection, @last_disconnection))}
    </span>
    """
  end

  defp ensure_subscribed(socket, device_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("devices:connection:#{device_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end

  defp latest_activity(nil, last_disconnection), do: last_disconnection
  defp latest_activity(last_connection, nil), do: last_connection

  defp latest_activity(%DateTime{} = conn_dt, %DateTime{} = disc_dt) do
    case DateTime.compare(conn_dt, disc_dt) do
      :lt -> disc_dt
      _ -> conn_dt
    end
  end

  defp format_timestamp(nil), do: "Never connected"

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end
end
