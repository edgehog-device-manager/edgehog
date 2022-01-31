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

defmodule Edgehog.Astarte.Device.CellularConnection.ModemStatus do
  @type t :: %__MODULE__{
          slot: String.t(),
          carrier: String.t() | nil,
          cell_id: integer() | nil,
          mobile_country_code: integer() | nil,
          mobile_network_code: integer() | nil,
          local_area_code: integer() | nil,
          registration_status: String.t() | nil,
          rssi: float() | nil,
          technology: String.t() | nil
        }

  @enforce_keys [
    :slot,
    :carrier,
    :cell_id,
    :mobile_country_code,
    :mobile_network_code,
    :local_area_code,
    :registration_status,
    :rssi,
    :technology
  ]
  defstruct @enforce_keys
end
