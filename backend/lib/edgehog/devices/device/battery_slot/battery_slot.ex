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

defmodule Edgehog.Devices.Device.BatterySlot do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Devices.Device.BatterySlot

  resource do
    description "Describes a battery slot of a device."
  end

  graphql do
    type :battery_slot
  end

  attributes do
    attribute :level_absolute_error, :float do
      description "Battery level measurement absolute error [0.0-100.0]."
      public? true
    end

    attribute :level_percentage, :float do
      description "Battery level estimated percentage [0.0%-100.0%]."
      public? true
    end

    attribute :slot, :string do
      description "The identifier of the battery slot."
      public? true
      allow_nil? false
    end

    attribute :status, BatterySlot.Status do
      description "The current status of the battery."
      public? true
    end
  end
end
