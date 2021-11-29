#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.SystemStatus do
  @enforce_keys [:timestamp]
  defstruct [
    :boot_id,
    :memory_free_bytes,
    :task_count,
    :uptime_milliseconds,
    :timestamp
  ]

  @type t() :: %__MODULE__{
          boot_id: String.t() | nil,
          memory_free_bytes: integer() | nil,
          task_count: integer() | nil,
          uptime_milliseconds: integer() | nil,
          timestamp: DateTime.t()
        }

  @behaviour Edgehog.Astarte.Device.SystemStatus.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.SystemStatus

  @interface "io.edgehog.devicemanager.SystemStatus"

  def get(%AppEngine{} = client, device_id) do
    # TODO: right now we request the whole interface at once and longinteger
    # values are returned as strings by Astarte, since the interface is of
    # type Object Aggregrate.
    # For details, see https://github.com/astarte-platform/astarte/issues/630
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @interface) do
      system_status_list =
        data["systemStatus"]
        |> Enum.map(fn ss ->
          %SystemStatus{
            boot_id: ss["bootId"],
            memory_free_bytes: parse_longinteger(ss["availMemoryBytes"]),
            task_count: ss["taskCount"],
            uptime_milliseconds: parse_longinteger(ss["uptimeMillis"]),
            timestamp: parse_datetime(ss["timestamp"])
          }
        end)

      case Enum.empty?(system_status_list) do
        true -> {:error, :system_status_not_found}
        false -> {:ok, List.first(system_status_list)}
      end
    end
  end

  defp parse_datetime(nil) do
    nil
  end

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  defp parse_longinteger(string) when is_binary(string) do
    case Integer.parse(string) do
      {integer, _remainder} -> integer
      _ -> nil
    end
  end

  defp parse_longinteger(_term) do
    nil
  end
end
