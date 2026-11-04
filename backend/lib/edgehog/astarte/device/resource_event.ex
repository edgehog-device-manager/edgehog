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

defmodule Edgehog.Astarte.Device.ResourceEvent do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.ResourceEvent.Behaviour

  use Ecto.Schema

  import Ecto.Changeset

  alias Astarte.Client.AppEngine
  alias Astarte.Client.AppEngine.Devices
  alias Edgehog.Astarte.Device.ResourceEvent

  @primary_key false
  embedded_schema do
    field :status, :string
    field :message, :string, default: ""
    field :add_info, {:array, :string}, default: []
    field :timestamp, :utc_datetime_usec
  end

  @type t() :: %__MODULE__{
          status: String.t() | nil,
          message: String.t(),
          add_info: [String.t()],
          timestamp: DateTime.t() | nil
        }

  @impl Edgehog.Astarte.Device.ResourceEvent.Behaviour
  def get(%AppEngine{} = client, device_id, interface, resource_id, query \\ []) do
    case Devices.get_datastream_data(client, device_id, interface,
           path: "/#{resource_id}",
           query: query
         ) do
      {:ok, %{"data" => events}} when is_list(events) ->
        parse_events(events)

      {:ok, %{"data" => data}} when data == %{} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_events(events) do
    result =
      Enum.reduce_while(events, {:ok, []}, fn raw_event, {:ok, acc} ->
        case parse_event(raw_event) do
          {:ok, event} -> {:cont, {:ok, [event | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_event(raw_event) when is_map(raw_event) do
    {add_info, raw_event} = Map.pop(raw_event, "addInfo")

    params =
      raw_event
      |> Map.take(["status", "message", "timestamp"])
      |> maybe_put("add_info", add_info)

    %ResourceEvent{}
    |> cast(params, [:status, :message, :add_info, :timestamp])
    |> validate_required([:status, :timestamp])
    |> apply_action(:validate)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
