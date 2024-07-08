#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.Calculations.CellularConnection do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Edgehog.Devices.Device.Modem

  @impl Calculation
  def load(_query, _opts, _context) do
    [:modem_status, :modem_properties]
  end

  @impl Calculation
  def calculate(devices, _opts, _context) do
    Enum.map(devices, &modem_list/1)
  end

  defp modem_list(%{modem_properties: modem_properties, modem_status: modem_status})
       when is_list(modem_properties) and is_list(modem_status) do
    slot_to_status = Map.new(modem_status, &{&1.slot, &1})

    Enum.map(modem_properties, fn modem ->
      modem_status = Map.get(slot_to_status, modem.slot, %{})

      attrs = %{
        slot: modem.slot,
        apn: modem.apn,
        imei: modem.imei,
        imsi: modem.imsi,
        carrier: Map.get(modem_status, :carrier),
        cell_id: Map.get(modem_status, :cell_id),
        mobile_country_code: Map.get(modem_status, :mobile_country_code),
        mobile_network_code: Map.get(modem_status, :mobile_network_code),
        local_area_code: Map.get(modem_status, :local_area_code),
        registration_status: Map.get(modem_status, :registration_status),
        rssi: Map.get(modem_status, :rssi),
        technology: Map.get(modem_status, :technology)
      }

      Modem
      |> Ash.Changeset.for_create(:create, attrs, domain: Edgehog.Devices)
      |> Ash.create!()
    end)
  end

  defp modem_list(_device), do: nil
end
