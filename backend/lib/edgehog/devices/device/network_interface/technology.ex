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

defmodule Edgehog.Devices.Device.NetworkInterface.Technology do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      ethernet: "Ethernet.",
      bluetooth: "Bluetooth.",
      cellular: "Cellular.",
      wifi: "WiFi."
    ]

  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :network_interface_technology
end
