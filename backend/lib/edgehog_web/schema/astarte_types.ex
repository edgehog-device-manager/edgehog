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

defmodule EdgehogWeb.Schema.AstarteTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Middleware
  alias EdgehogWeb.Resolvers

  @desc """
  Describes a set of filters to apply when fetching a list of devices.

  When multiple filters are specified, they are applied in an AND fashion to \
  further refine the results.
  """
  input_object :device_filter do
    @desc "Whether to return devices connected or not to Astarte."
    field :online, :boolean

    @desc """
    A string to match against the device ID. The match is case-insensitive \
    and tests whether the string is included in the device ID.
    """
    field :device_id, :string

    @desc """
    A string to match against the part number of the device's appliance model.
    The match is case-insensitive and tests whether the string is included in \
    the part number of the device's appliance model.
    """
    field :appliance_model_part_number, :string

    @desc """
    A string to match against the handle of the device's appliance model.
    The match is case-insensitive and tests whether the string is included in \
    the handle of the device's appliance model.
    """
    field :appliance_model_handle, :string

    @desc """
    A string to match against the name of the device's appliance model.
    The match is case-insensitive and tests whether the string is included in \
    the name of the device's appliance model.
    """
    field :appliance_model_name, :string

    @desc """
    A string to match against the part number of the device's hardware type.
    The match is case-insensitive and tests whether the string is included in \
    the part number of the device's hardware type.
    """
    field :hardware_type_part_number, :string

    @desc """
    A string to match against the handle of the device's hardware type.
    The match is case-insensitive and tests whether the string is included in \
    the handle of the device's hardware type.
    """
    field :hardware_type_handle, :string

    @desc """
    A string to match against the name of the device's hardware type.
    The match is case-insensitive and tests whether the string is included in \
    the name of the device's hardware type.
    """
    field :hardware_type_name, :string
  end

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

  @desc """
  Describes the position of a device.

  The position is estimated by means of Edgehog's Geolocation modules and the \
  data published by the device.
  """
  object :device_location do
    @desc "The latitude coordinate."
    field :latitude, non_null(:float)

    @desc "The longitude coordinate."
    field :longitude, non_null(:float)

    @desc "The accuracy of the measurement, in meters."
    field :accuracy, :float

    @desc "The formatted address estimated for the position."
    field :address, :string

    @desc "The date at which the measurement was made."
    field :timestamp, non_null(:datetime)
  end

  @desc "Describes an operating system bundle of a device."
  object :os_bundle do
    @desc "The name of the bundle."
    field :name, :string

    @desc "The version of the bundle."
    field :version, :string

    @desc "Human readable build identifier of the bundle."
    field :build_id, :string

    @desc """
    A unique string that identifies the release, usually the bundle hash.
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
      resolve &Resolvers.Astarte.battery_status_to_enum/3
      middleware Middleware.ErrorHandler
    end
  end

  @desc """
  Denotes a device instance that connects and exchanges data.

  Each Device is associated to a specific ApplianceModel, which in turn is \
  associated to a specific HardwareType.
  A Device also exposes info about its connection status and some sets of \
  data read by its operating system.
  """
  node object(:device) do
    @desc "The display name of the device."
    field :name, non_null(:string)

    @desc "The device ID used to connect to the Astarte cluster."
    field :device_id, non_null(:string)

    @desc "Tells whether the device is connected or not to Astarte."
    field :online, non_null(:boolean)

    @desc "The date at which the device last connected to Astarte."
    field :last_connection, :datetime

    @desc "The date at which the device last disconnected from Astarte."
    field :last_disconnection, :datetime

    @desc "The appliance model of the device."
    field :appliance_model, :appliance_model

    @desc "Info read from the device's hardware."
    field :hardware_info, :hardware_info do
      resolve &Resolvers.Astarte.get_hardware_info/3
      middleware Middleware.ErrorHandler
    end

    @desc "The estimated location of the device."
    field :location, :device_location do
      resolve &Resolvers.Astarte.fetch_device_location/3
      middleware Middleware.ErrorHandler
    end

    @desc "The current usage of the storage units of the device."
    field :storage_usage, list_of(non_null(:storage_unit)) do
      resolve &Resolvers.Astarte.fetch_storage_usage/3
      middleware Middleware.ErrorHandler
    end

    @desc "The current status of the operating system of the device."
    field :system_status, :system_status do
      resolve &Resolvers.Astarte.fetch_system_status/3
      middleware Middleware.ErrorHandler
    end

    @desc "The list of WiFi Access Points found by the device."
    field :wifi_scan_results, list_of(non_null(:wifi_scan_result)) do
      resolve &Resolvers.Astarte.fetch_wifi_scan_results/3
      middleware Middleware.ErrorHandler
    end

    @desc "The status of the battery slots of the device."
    field :battery_status, list_of(non_null(:battery_slot)) do
      resolve &Resolvers.Astarte.fetch_battery_status/3
      middleware Middleware.ErrorHandler
    end

    @desc "Information about the operating system bundle of the device."
    field :os_bundle, :os_bundle do
      resolve &Resolvers.Astarte.fetch_os_bundle/3
      middleware Middleware.ErrorHandler
    end

    @desc "Information about the operating system of the device."
    field :os_info, :os_info do
      resolve &Resolvers.Astarte.fetch_os_info/3
      middleware Middleware.ErrorHandler
    end
  end

  object :astarte_queries do
    @desc "Fetches the list of all devices."
    field :devices, non_null(list_of(non_null(:device))) do
      @desc "An optional set of filters to apply when fetching the devices."
      arg :filter, :device_filter
      resolve &Resolvers.Astarte.list_devices/3
    end

    @desc "Fetches a single device."
    field :device, :device do
      @desc "The ID of the device."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :device
      resolve &Resolvers.Astarte.find_device/2
    end
  end
end
