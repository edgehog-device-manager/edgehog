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

defmodule Edgehog.Devices.Device.Modem do
  use Ash.Resource,
    data_layer: :embedded,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Devices.Device.Modem

  resource do
    description "Describes a modem of a device."
  end

  graphql do
    type :modem
  end

  attributes do
    attribute :apn, :string do
      description "The operator apn address."
      public? true
    end

    attribute :carrier, :string do
      description "Carrier operator name."
      public? true
    end

    attribute :cell_id, :integer do
      description "Unique identifier of the cell."
      public? true
    end

    attribute :imei, :string do
      description "The modem IMEI code."
      public? true
    end

    attribute :imsi, :string do
      description "The SIM IMSI code."
      public? true
    end

    attribute :local_area_code, :integer do
      description "The Local Area Code."
      public? true
    end

    attribute :mobile_country_code, :integer do
      description "The cell tower's Mobile Country Code (MCC)."
      public? true
    end

    attribute :mobile_network_code, :integer do
      description "The cell tower's Mobile Network Code."
      public? true
    end

    attribute :registration_status, Modem.RegistrationStatus do
      description "The GSM/LTE registration status of the modem."
      public? true
    end

    attribute :rssi, :float do
      description "Signal strength in dBm."
      public? true
    end

    attribute :slot, :string do
      description "The identifier of the modem."
      public? true
      allow_nil? false
    end

    attribute :technology, Modem.Technology do
      description "The access technology of the serving cell."
      public? true
    end
  end
end
