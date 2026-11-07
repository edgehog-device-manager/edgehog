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

defmodule EdgehogWeb.DevicesLive.TagsCellComponent do
  @moduledoc """
  Reactive table cell LiveComponent displaying a device's assigned tags.

  Subscribes to `"devices:tags:<id>"` so tag additions and removals update the
  rendered tag badges in place.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(%{device: device, tenant: tenant} = assigns, socket) do
    device = ensure_tags_loaded(device, tenant)

    socket =
      socket
      |> assign(assigns)
      |> assign(:tags, device_tags(device))
      |> ensure_subscribed(device.id)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-wrap gap-1">
      <span
        :for={tag <- @tags}
        class="badge badge-soft badge-primary badge-sm font-medium"
      >
        {tag.name}
      </span>
      <span :if={@tags == []} class="text-xs text-base-content/40">
        No tags
      </span>
    </div>
    """
  end

  defp ensure_subscribed(socket, device_id) do
    if connected?(socket) and not Map.get(socket.assigns, :subscribed?, false) do
      EdgehogWeb.Endpoint.subscribe("devices:tags:#{device_id}")
      assign(socket, :subscribed?, true)
    else
      socket
    end
  end

  defp ensure_tags_loaded(device, tenant) do
    if Ash.Resource.loaded?(device, :tags) do
      device
    else
      Ash.load!(device, :tags, tenant: tenant, authorize?: false)
    end
  end

  defp device_tags(%{tags: tags}) when is_list(tags), do: tags
  defp device_tags(_device), do: []
end
