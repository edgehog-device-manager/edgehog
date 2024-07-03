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

defmodule Edgehog.Astarte.Device.CellularConnectionTest do
  use ExUnit.Case

  alias Edgehog.Astarte.Device.CellularConnection
  alias Edgehog.Astarte.Device.CellularConnection.ModemProperties
  alias Edgehog.Astarte.Device.CellularConnection.ModemStatus

  @modem1_properties_data %{
    "apn" => "company.com",
    "imei" => "509504877678976",
    "imsi" => "313460000000001"
  }
  @modem1_propetries %ModemProperties{
    slot: "modem_1",
    apn: "company.com",
    imei: "509504877678976",
    imsi: "313460000000001"
  }

  describe "parse_modem_properties/1" do
    test "correctly parses ModemProperties" do
      assert @modem1_propetries ==
               CellularConnection.parse_modem_properties({"modem_1", @modem1_properties_data})
    end
  end

  describe "parse_properties_data/1" do
    test "correctly parses CellularConnectionProperties interface data" do
      data = %{
        "modem_1" => @modem1_properties_data,
        "modem_2" => %{
          "apn" => "internet",
          "imei" => "338897112874161"
        }
      }

      assert [
               @modem1_propetries,
               %ModemProperties{
                 slot: "modem_2",
                 apn: "internet",
                 imei: "338897112874161",
                 imsi: nil
               }
             ] == CellularConnection.parse_properties_data(data)
    end
  end

  @modem1_status_data %{
    "carrier" => "Carrier",
    "cellId" => "170402199",
    "mobileCountryCode" => 310,
    "mobileNetworkCode" => 410,
    "localAreaCode" => 35_632,
    "registrationStatus" => "Registered",
    "rssi" => -60,
    "technology" => "GSM",
    "timestamp" => "2022-01-19T12:00:00.000Z"
  }
  @modem1_status %ModemStatus{
    slot: "modem_1",
    carrier: "Carrier",
    cell_id: 170_402_199,
    mobile_country_code: 310,
    mobile_network_code: 410,
    local_area_code: 35_632,
    registration_status: "Registered",
    rssi: -60,
    technology: "GSM"
  }

  describe "parse_modem_status/1" do
    test "correctly parses ModemStatus" do
      assert @modem1_status ==
               CellularConnection.parse_modem_status({"modem_1", [@modem1_status_data]})
    end
  end

  describe "parse_status_data/1" do
    test "correctly parses CellularConnectionStatus interface data" do
      data = %{
        "modem_1" => [@modem1_status_data],
        "modem_2" => [
          %{
            "registrationStatus" => "NotRegistered",
            "timestamp" => "2022-01-19T12:00:00.000Z"
          }
        ]
      }

      assert [
               @modem1_status,
               %ModemStatus{
                 slot: "modem_2",
                 carrier: nil,
                 cell_id: nil,
                 mobile_country_code: nil,
                 mobile_network_code: nil,
                 local_area_code: nil,
                 registration_status: "NotRegistered",
                 rssi: nil,
                 technology: nil
               }
             ] == CellularConnection.parse_status_data(data)
    end
  end
end
