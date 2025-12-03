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

defmodule EdgehogWeb.Channel.RoomChannel do
  use Phoenix.Channel

  @impl true
  def join("rooms:" <> room_id, _params, socket) do
    tenant = socket.assigns[:current_tenant]

    if tenant do
      socket = assign(socket, :room_id, room_id)
      {:ok, %{room_id: room_id}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("message", %{"body" => body}, socket) do
    room_id = socket.assigns.room_id
    tenant = socket.assigns.current_tenant

    broadcast!(socket, "message", %{
      body: body,
      room_id: room_id,
      timestamp: DateTime.utc_now()
    })

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{pong: true}}, socket}
  end

  @impl true
  def handle_in(event, payload, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    room_id = socket.assigns[:room_id]
    :ok
  end
end
