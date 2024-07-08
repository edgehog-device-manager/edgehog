#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Astarte.Device.CellularConnection do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.CellularConnection.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.CellularConnection.ModemProperties
  alias Edgehog.Astarte.Device.CellularConnection.ModemStatus

  @properties_interface "io.edgehog.devicemanager.CellularConnectionProperties"
  @status_interface "io.edgehog.devicemanager.CellularConnectionStatus"

  @impl Edgehog.Astarte.Device.CellularConnection.Behaviour
  def get_modem_properties(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_properties_data(client, device_id, @properties_interface) do
      modems = parse_properties_data(data)

      {:ok, modems}
    end
  end

  def parse_properties_data(data), do: Enum.map(data, &parse_modem_properties/1)

  def parse_modem_properties({slot, properties_data}) do
    %ModemProperties{
      slot: slot,
      apn: properties_data["apn"],
      imei: properties_data["imei"],
      imsi: properties_data["imsi"]
    }
  end

  @impl Edgehog.Astarte.Device.CellularConnection.Behaviour
  def get_modem_status(%AppEngine{} = client, device_id) do
    # TODO: right now we request the whole interface at once and longinteger
    # values are returned as strings by Astarte, since the interface is of
    # type Object Aggregrate.
    # For details, see https://github.com/astarte-platform/astarte/issues/630
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_datastream_data(client, device_id, @status_interface, query: [limit: 1]) do
      modems = parse_status_data(data)

      {:ok, modems}
    end
  end

  def parse_status_data(data), do: Enum.map(data, &parse_modem_status/1)

  def parse_modem_status({slot, [status_data]}) do
    %ModemStatus{
      slot: slot,
      carrier: status_data["carrier"],
      cell_id: parse_longinteger(status_data["cellId"]),
      mobile_country_code: status_data["mobileCountryCode"],
      mobile_network_code: status_data["mobileNetworkCode"],
      local_area_code: status_data["localAreaCode"],
      registration_status: status_data["registrationStatus"],
      rssi: status_data["rssi"],
      technology: status_data["technology"]
    }
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
