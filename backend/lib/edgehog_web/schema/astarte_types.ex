#
# This file is part of Edgehog.
#
# Copyright 2021-2022 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.AstarteTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Middleware
  alias EdgehogWeb.Resolvers

  @desc """
  Describes hardware-related info of a device.

  It exposes data read by a device's operating system about the underlying \
  hardware.
  """
  object :hardware_info do
    @desc "The architecture of the CPU."
    field :cpu_architecture, :string

    @desc "The reference code of the CPU model."
    field :cpu_model, :string

    @desc "The display name of the CPU model."
    field :cpu_model_name, :string

    @desc "The vendor's name."
    field :cpu_vendor, :string

    @desc "The Bytes count of memory."
    field :memory_total_bytes, :integer
  end

  @desc "Describes the current usage of a storage unit on a device."
  object :storage_unit do
    @desc "The label of the storage unit."
    field :label, non_null(:string)

    @desc "The total number of bytes of the storage unit."
    field :total_bytes, :integer

    @desc "The number of free bytes of the storage unit."
    field :free_bytes, :integer
  end

  @desc "Describes an operating system's base image for a device."
  object :base_image do
    @desc "The name of the image."
    field :name, :string

    @desc "The version of the image."
    field :version, :string

    @desc "Human readable build identifier of the image."
    field :build_id, :string

    @desc """
    A unique string that identifies the release, usually the image hash.
    """
    field :fingerprint, :string
  end

  @desc "Describes an operating system of a device."
  object :os_info do
    @desc "The name of the operating system."
    field :name, :string

    @desc "The version of the operating system."
    field :version, :string
  end

  @desc """
  Describes the current status of the operating system of a device.
  """
  object :system_status do
    @desc "The identifier of the performed boot sequence."
    field :boot_id, :string

    @desc "The number of free bytes of memory."
    field :memory_free_bytes, :integer

    @desc "The number of running tasks on the system."
    field :task_count, :integer

    @desc "The number of milliseconds since the last system boot."
    field :uptime_milliseconds, :integer

    @desc "The date at which the system status was read."
    field :timestamp, non_null(:datetime)
  end

  @desc """
  Describes the list of WiFi Access Points found by the device.
  """
  object :wifi_scan_result do
    @desc "The channel used by the Access Point."
    field :channel, :integer

    @desc "Indicates whether the device is connected to the Access Point."
    field :connected, :boolean

    @desc "The ESSID advertised by the Access Point."
    field :essid, :string

    @desc "The MAC address advertised by the Access Point."
    field :mac_address, :string

    @desc "The power of the radio signal, measured in dBm."
    field :rssi, :integer

    @desc "The date at which the device found the Access Point."
    field :timestamp, non_null(:datetime)
  end

  @desc """
  The current status of the battery.
  """
  enum :battery_status do
    @desc "The battery is charging."
    value :charging
    @desc "The battery is discharging."
    value :discharging
    @desc "The battery is idle."
    value :idle

    @desc """
    The battery is either in a charging or in an idle state, \
    since the hardware doesn't allow to distinguish between them.
    """
    value :either_idle_or_charging
    @desc "The battery is in a failed state."
    value :failure
    @desc "The battery is removed."
    value :removed
    @desc "The battery status cannot be determined."
    value :unknown
  end

  @desc "Describes a battery slot of a device."
  object :battery_slot do
    @desc "The identifier of the battery slot."
    field :slot, non_null(:string)

    @desc "Battery level estimated percentage [0.0%-100.0%]"
    field :level_percentage, :float

    @desc "Battery level measurement absolute error [0.0-100.0]"
    field :level_absolute_error, :float

    @desc "The current status of the battery."
    field :status, :battery_status do
      resolve &Resolvers.Astarte.resolve_battery_status/3
      middleware Middleware.ErrorHandler
    end
  end

  @desc """
  The current GSM/LTE registration status of the modem.
  """
  enum :modem_registration_status do
    @desc "Not registered, modem is not currently searching a new operator to register to."
    value :not_registered
    @desc "Registered, home network."
    value :registered
    @desc "Not registered, but modem is currently searching a new operator to register to."
    value :searching_operator
    @desc "Registration denied."
    value :registration_denied
    @desc "Unknown (e.g. out of GERAN/UTRAN/E-UTRAN coverage)."
    value :unknown
    @desc "Registered, roaming."
    value :registered_roaming
  end

  @desc """
  The current access technology of the serving cell.
  """
  enum :modem_technology do
    @desc "GSM."
    value :gsm
    @desc "GSM Compact."
    value :gsm_compact
    @desc "UTRAN."
    value :utran
    @desc "GSM with EGPRS."
    value :gsm_egprs
    @desc "UTRAN with HSDPA."
    value :utran_hsdpa
    @desc "UTRAN with HSUPA."
    value :utran_hsupa
    @desc "UTRAN with HSDPA and HSUPA."
    value :utran_hsdpa_hsupa
    @desc "E-UTRAN."
    value :eutran
  end

  @desc "Describes a modem of a device."
  object :modem do
    @desc "The identifier of the modem."
    field :slot, non_null(:string)
    @desc "The operator apn address."
    field :apn, :string
    @desc "The modem IMEI code."
    field :imei, :string
    @desc "The SIM IMSI code."
    field :imsi, :string
    @desc "Carrier operator name."
    field :carrier, :string
    @desc "Unique identifier of the cell."
    field :cell_id, :integer
    @desc "The cell tower's Mobile Country Code (MCC)."
    field :mobile_country_code, :integer
    @desc "The cell tower's Mobile Network Code."
    field :mobile_network_code, :integer
    @desc "The Local Area Code."
    field :local_area_code, :integer
    @desc "The current registration status of the modem."
    field :registration_status, :modem_registration_status do
      resolve &Resolvers.Astarte.resolve_modem_registration_status/3
      middleware Middleware.ErrorHandler
    end

    @desc "Signal strength in dBm."
    field :rssi, :float

    @desc "Access Technology"
    field :technology, :modem_technology do
      resolve &Resolvers.Astarte.resolve_modem_technology/3
      middleware Middleware.ErrorHandler
    end
  end

  @desc "Describes an Edgehog runtime."
  object :runtime_info do
    @desc "The name of the Edgehog runtime."
    field :name, :string

    @desc "The version of the Edgehog runtime."
    field :version, :string

    @desc "The environment of the Edgehog runtime."
    field :environment, :string

    @desc "The URL that uniquely identifies the Edgehog runtime implementation."
    field :url, :string
  end

  @desc "Led behavior"
  enum :led_behavior do
    @desc "Blink for 60 seconds."
    value :blink
    @desc "Double blink for 60 seconds."
    value :double_blink
    @desc "Slow blink for 60 seconds."
    value :slow_blink
  end

  object :astarte_mutations do
    @desc "Sets led behavior."
    payload field :set_led_behavior do
      input do
        @desc "The GraphQL ID (not the Astarte Device ID) of the target device"
        field :device_id, non_null(:id)

        @desc "The led behavior"
        field :behavior, non_null(:led_behavior)
      end

      output do
        @desc "The resulting led behavior."
        field :behavior, non_null(:led_behavior)
      end

      middleware Absinthe.Relay.Node.ParseIDs, device_id: :device
      resolve &Resolvers.Astarte.set_led_behavior/2
    end
  end
end
