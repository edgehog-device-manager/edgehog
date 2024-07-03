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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Astarte.Device.DeviceStatus do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.DeviceStatus.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.DeviceStatus
  alias Edgehog.Astarte.InterfaceVersion

  defstruct [
    :attributes,
    :groups,
    :introspection,
    :last_connection,
    :last_disconnection,
    :last_seen_ip,
    :online,
    :previous_interfaces
  ]

  @impl Edgehog.Astarte.Device.DeviceStatus.Behaviour
  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_device_status(client, device_id) do
      device_status = %DeviceStatus{
        attributes: data["attributes"],
        groups: data["groups"],
        introspection: build_introspection(data["introspection"]),
        last_connection: parse_datetime(data["last_connection"]),
        last_disconnection: parse_datetime(data["last_disconnection"]),
        last_seen_ip: data["last_seen_ip"],
        online: data["connected"] || false,
        previous_interfaces: data["previous_interfaces"]
      }

      {:ok, device_status}
    end
  end

  defp build_introspection(nil) do
    %{}
  end

  defp build_introspection(interfaces_map) do
    Map.new(interfaces_map, fn {name, info} ->
      {name, %InterfaceVersion{major: info["major"], minor: info["minor"]}}
    end)
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
end
