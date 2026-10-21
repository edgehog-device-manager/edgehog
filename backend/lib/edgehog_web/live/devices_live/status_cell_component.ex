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

defmodule EdgehogWeb.DevicesLive.StatusCellComponent do
  @moduledoc """
  Reactive table cell LiveComponent displaying a device's online/offline status.

  Subscribes to `"devices:online:<id>"` and `"devices:offline:<id>"` so status
  transitions update this cell in place.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{device: device} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:online, device.online)
      |> ensure_subscribed(device.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id} class="inline-flex items-center">
      <span
        :if={@online}
        data-status="online"
        class="badge badge-soft badge-success gap-1.5 font-semibold"
      >
        <span class="status status-success animate-pulse"></span> Online
      </span>
      <span
        :if={!@online}
        data-status="offline"
        class="badge badge-ghost border-base-300 gap-1.5 text-base-content/65"
      >
        <span class="status"></span> Offline
      </span>
    </div>
    """
  end

  defp ensure_subscribed(socket, device_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("devices:online:#{device_id}")
      EdgehogWeb.Endpoint.subscribe("devices:offline:#{device_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end
end
