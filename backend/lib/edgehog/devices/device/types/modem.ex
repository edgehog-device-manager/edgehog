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

defmodule Edgehog.Devices.Device.Types.Modem do
  defstruct [
    :slot,
    :apn,
    :imei,
    :imsi,
    :carrier,
    :cell_id,
    :mobile_country_code,
    :mobile_network_code,
    :local_area_code,
    :registration_status,
    :rssi,
    :technology
  ]

  use Ash.Type.NewType,
    subtype_of: :struct,
    constraints: [instance_of: __MODULE__]

  use AshGraphql.Type

  @impl true
  def graphql_type(_), do: :modem
end
