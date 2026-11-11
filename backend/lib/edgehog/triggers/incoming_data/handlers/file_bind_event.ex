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

defmodule Edgehog.Triggers.IncomingData.Handlers.FileBindEvent do
  @moduledoc """
  FileBind Event handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Containers.Calculations.ResourceEvents
  alias Edgehog.Containers.FileBind.Types.Event
  alias EdgehogWeb.Endpoint

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, %{timestamp: timestamp, tenant: tenant}) do
    "/" <> file_bind_id = event.path

    %{
      "status" => status,
      "message" => message
    } = event.value

    add_info = Map.get(event.value, "addInfo", [])

    with {:ok, file_bind} <-
           Containers.fetch_file_bind(file_bind_id,
             tenant: tenant,
             load: [container_deployment: :deployments]
           ) do
      raw_event = %{
        status: status,
        message: message,
        add_info: add_info,
        timestamp: timestamp
      }

      payload =
        file_bind
        |> ResourceEvents.cast_event!(raw_event, Event)
        |> Map.put(:__type__, Event.graphql_type([]))

      container_deployment = file_bind.container_deployment

      release_topics =
        Enum.map(container_deployment.deployments, fn d ->
          {:release_deployment_events, "#{tenant.tenant_id}:#{d.id}"}
        end)

      topics = [
        {:file_bind_deployment_events, "#{tenant.tenant_id}:#{file_bind.id}"},
        {:container_deployment_events, "#{tenant.tenant_id}:#{container_deployment.id}"}
        | release_topics
      ]

      Absinthe.Subscription.publish(Endpoint, payload, topics)
      :ok
    end
  end
end
