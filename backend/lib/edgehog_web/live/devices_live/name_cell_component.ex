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

defmodule EdgehogWeb.DevicesLive.NameCellComponent do
  @moduledoc """
  Reactive table cell LiveComponent displaying a device's friendly name.

  Subscribes to `"devices:name:<id>"` to update the display name in place.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{device: device} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:name, device.name)
      |> ensure_subscribed(device.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col">
      <span class="font-semibold text-base-content">
        {@name || "Unnamed Device"}
      </span>
    </div>
    """
  end

  defp ensure_subscribed(socket, device_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("devices:name:#{device_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end
end
