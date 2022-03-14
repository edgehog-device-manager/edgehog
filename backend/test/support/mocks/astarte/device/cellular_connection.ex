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

defmodule Edgehog.Mocks.Astarte.Device.CellularConnection do
  @behaviour Edgehog.Astarte.Device.CellularConnection.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.CellularConnection.{ModemProperties, ModemStatus}

  @impl true
  def get_modem_properties(%AppEngine{} = _client, _device_id) do
    modem_properties_list = [
      %ModemProperties{
        slot: "modem_1",
        apn: "company.com",
        imei: "509504877678976",
        imsi: "313460000000001"
      },
      %ModemProperties{
        slot: "modem_2",
        apn: "internet",
        imei: "338897112874161",
        imsi: nil
      },
      %ModemProperties{
        slot: "modem_3",
        apn: "internet",
        imei: "338897112874162",
        imsi: nil
      }
    ]

    {:ok, modem_properties_list}
  end

  @impl true
  def get_modem_status(%AppEngine{} = _client, _device_id) do
    modem_status_list = [
      %ModemStatus{
        slot: "modem_1",
        carrier: "Carrier",
        cell_id: 170_402_199,
        mobile_country_code: 310,
        mobile_network_code: 410,
        local_area_code: 35632,
        registration_status: "Registered",
        rssi: -60,
        technology: "GSM"
      },
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
    ]

    {:ok, modem_status_list}
  end
end
