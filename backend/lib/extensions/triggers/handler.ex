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

defmodule Ash.Astarte.Triggers.Handler do
  @moduledoc """
  Processes incoming Astarte trigger payloads and dispatches them to configured handlers.

  This module acts as the orchestration layer for Astarte events within the Ash/Edgehog 
  ecosystem. It performs payload validation, realm lookups, and identifies which 
  resource-specific or fallback handlers should process a given event.

  ## Processing Flow

  1.  **Validation**: Ensures the realm name is valid.
  2.  **Payload Casting**: Attempts to cast the raw data into an `Ash.Astarte.Triggers.Payload`.
  3.  **Realm Lookup**: Fetches the associated `Edgehog.Astarte.Realm` record to provide 
      context for the handler.
  4.  **Handler Discovery**: 
      * Identifies handlers registered on the specific resource associated with the event.
      * Applies attribute-based filters (configured via the handler definition) to 
          ensure only relevant events are processed.
      * If no specific handlers are found or the data is unstructured, it defaults to 
          **Fallback Handlers** defined in the domain configuration.
  5.  **Dispatch**: Calls `handle_event/3` on each identified handler module.

  ## Event Context

  When a handler is invoked, it receives a `context` map containing:
  * `:tenant` - The current tenant identifier.
  * `:realm_id` - The ID of the Astarte realm.
  * `:device_id` - The ID of the device that triggered the event.
  * `:timestamp` - The ISO8601 or Unix timestamp of the event.
  """

  alias Ash.Astarte.Triggers.Payload
  alias Edgehog.Astarte

  require Ash.Query
  require Logger

  def handle_trigger(tenant, realm, data) do
    read_query =
      Astarte.Realm
      |> Ash.Query.select([:id])
      |> Ash.Query.load(tenant: [:tenant_id])

    with {:ok, realm_name} <- valid_realm?(realm),
         {:ok, payload, handlers} <- get_handlers(data),
         {:ok, realm} <-
           Astarte.fetch_realm_by_name(realm_name, query: read_query, tenant: tenant) do
      {event, device_id, timestamp} = unpack_payload(payload)

      context = %{
        tenant: tenant,
        realm_id: realm.id,
        device_id: device_id,
        timestamp: timestamp
      }

      function = :handle_event
      args = [event, [], context]

      map_handling(handlers, function, args, tenant, realm.id)

      :ok
    end
  end

  defp map_handling(ms, f, a, tenant, realm_id) do
    [event | _] = a
    [m | _] = ms

    handled = apply(m, f, a)

    with {:error, error} <- handled do
      opts = [error: error, trigger: event, tenant: tenant, realm_id: realm_id]
      Logger.error("Error handling a trigger", opts)
    end
  end

  defp unpack_payload(%Payload{device_id: device_id, timestamp: timestamp, event: event}) do
    %Ash.Union{
      value: event
    } = event

    {event, device_id, timestamp}
  end

  defp unpack_payload(raw_data) do
    %{
      "device_id" => device_id,
      "timestamp" => timestamp,
      "event" => event
    } = raw_data

    {event, device_id, timestamp}
  end

  defp get_handlers(data) do
    case Payload.cast_input(data, []) do
      {:ok, payload} -> handlers_from_payload(payload)
      {:error, _error} -> handlers_from_data(data)
    end
  end

  defp handlers_from_payload(%Payload{event: %Ash.Union{value: event}} = payload) do
    handlers =
      event.__struct__
      |> Ash.Astarte.Triggers.Resource.Info.handlers()
      |> Enum.filter(&against_handler_filter(&1, event))
      |> Enum.map(& &1.module)

    {:ok, payload, handlers}
  end

  defp handlers_from_data(data) do
    if valid_data?(data),
      do: {:ok, data, fallback_handlers()},
      else: {:error, :bad_request}
  end

  defp fallback_handlers do
    :edgehog
    |> Application.get_env(:triggers)
    |> Ash.Astarte.Triggers.Domain.Info.fallback_handlers()
    |> Enum.map(& &1.module)
  end

  defp valid_data?(data) do
    %{
      "device_id" => device_id,
      "timestamp" => timestamp,
      "event" => event
    } = data

    valid_timestamp = match?({:error, _}, DateTime.from_unix(timestamp))

    is_binary(device_id) && valid_timestamp && is_map(event)
  end

  defp valid_realm?(realm_name) do
    if is_nil(realm_name),
      do: {:error, :invalid_realm_name},
      else: {:ok, realm_name}
  end

  defp against_handler_filter(handler, event) do
    case Map.get(handler, :filter) do
      nil ->
        true

      filters ->
        Enum.all?(filters, fn {attribute, value} ->
          Map.get(event, attribute) == value
        end)
    end
  end
end
