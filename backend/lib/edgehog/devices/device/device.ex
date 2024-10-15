#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule Edgehog.Devices.Device do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Devices,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.Changes.NormalizeTagName
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.ImageCredentials
  alias Edgehog.Devices.Device.BatterySlot
  alias Edgehog.Devices.Device.Calculations
  alias Edgehog.Devices.Device.Changes
  alias Edgehog.Devices.Device.LedBehavior
  alias Edgehog.Devices.Device.ManualActions
  alias Edgehog.Devices.Device.ManualRelationships
  alias Edgehog.Devices.Device.Modem
  alias Edgehog.Devices.Device.NetworkInterface
  alias Edgehog.Devices.Device.Types

  resource do
    description """
    Denotes a device instance that connects and exchanges data.

    Each Device is associated to a specific SystemModel, which in turn is
    associated to a specific HardwareType.
    A Device also exposes info about its connection status and some sets of \
    data read by its operating system.
    """
  end

  graphql do
    type :device
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :device_id,
        :name,
        :part_number,
        :online,
        :realm_id,
        :last_connection,
        :last_disconnection
      ]
    end

    create :from_device_connected_event do
      upsert? true
      upsert_identity :unique_realm_device_id
      upsert_fields [:online, :last_connection, :updated_at]

      accept [:realm_id]
      argument :device_id, :string, allow_nil?: false
      argument :timestamp, :datetime, allow_nil?: false

      change Changes.InitializeFromDeviceStatus

      # Only if created
      change set_attribute(:device_id, arg(:device_id))
      change set_attribute(:name, arg(:device_id))

      # If updated or created
      change set_attribute(:online, true)
      change set_attribute(:last_connection, arg(:timestamp))
    end

    create :from_device_disconnected_event do
      upsert? true
      upsert_identity :unique_realm_device_id
      upsert_fields [:online, :last_disconnection, :updated_at]

      accept [:realm_id]
      argument :device_id, :string, allow_nil?: false
      argument :timestamp, :datetime, allow_nil?: false

      change Changes.InitializeFromDeviceStatus

      # Only if created
      change set_attribute(:device_id, arg(:device_id))
      change set_attribute(:name, arg(:device_id))

      # If updated or created
      change set_attribute(:online, false)
      change set_attribute(:last_disconnection, arg(:timestamp))
    end

    create :from_serial_number_event do
      upsert? true
      upsert_identity :unique_realm_device_id
      upsert_fields [:online, :serial_number, :updated_at]

      accept [:serial_number, :realm_id]
      argument :device_id, :string, allow_nil?: false

      change Changes.InitializeFromDeviceStatus

      # Only if created
      change set_attribute(:device_id, arg(:device_id))
      change set_attribute(:name, arg(:device_id))

      # We also set the device to online since it sent some data. This helps resynchronizing the
      # online state for long-running devices if a device connected trigger is missed
      change set_attribute(:online, true)
    end

    create :from_part_number_event do
      upsert? true
      upsert_identity :unique_realm_device_id
      upsert_fields [:online, :part_number, :updated_at]

      accept [:part_number, :realm_id]
      argument :device_id, :string, allow_nil?: false

      change Changes.InitializeFromDeviceStatus

      # Only if created
      change set_attribute(:device_id, arg(:device_id))
      change set_attribute(:name, arg(:device_id))

      # We also set the device to online since it sent some data. This helps resynchronizing the
      # online state for long-running devices if a device connected trigger is missed
      change set_attribute(:online, true)
    end

    create :from_unhandled_event do
      upsert? true
      upsert_identity :unique_realm_device_id
      upsert_fields [:online, :updated_at]

      accept [:realm_id]
      argument :device_id, :string, allow_nil?: false

      change Changes.InitializeFromDeviceStatus

      # Only if created
      change set_attribute(:device_id, arg(:device_id))
      change set_attribute(:name, arg(:device_id))

      # We also set the device to online since it sent some data. This helps resynchronizing the
      # online state for long-running devices if a device connected trigger is missed
      change set_attribute(:online, true)
    end

    update :update do
      description "Updates a device."

      accept [:name]
    end

    update :add_tags do
      description "Add tags to a device."

      # Needed because manage_relationship is not atomic
      require_atomic? false

      argument :tags, {:array, :string} do
        allow_nil? false
        constraints min_length: 1, items: [min_length: 1]
      end

      change {NormalizeTagName, argument: :tags}

      change manage_relationship(:tags,
               on_lookup: :relate,
               on_no_match: :create,
               value_is_key: :name,
               use_identities: [:name]
             )
    end

    update :remove_tags do
      description "Remove tags from a device."

      # Needed because manage_relationship is not atomic
      require_atomic? false

      argument :tags, {:array, :string} do
        allow_nil? false
        constraints min_length: 1, items: [min_length: 1]
      end

      change {NormalizeTagName, argument: :tags}

      change manage_relationship(:tags,
               on_match: :unrelate,
               on_no_match: :ignore,
               on_missing: :ignore,
               value_is_key: :name,
               use_identities: [:name]
             )
    end

    update :from_device_status do
      accept [:online, :last_connection, :last_disconnection]
    end

    update :set_led_behavior do
      description "Sets led behavior."
      argument :behavior, LedBehavior, description: "The led behavior.", allow_nil?: false
      manual ManualActions.SetLedBehavior
    end

    update :send_create_image do
      description "Sends a create image request to the device."

      argument :image, :struct do
        constraints instance_of: Image
        description "The image the device will pull."
        allow_nil? false
      end

      argument :credentials, :struct do
        constraints instance_of: ImageCredentials
        description "The credentials to use."
        allow_nil? true
      end

      manual ManualActions.SendCreateImageRequest
    end
  end

  attributes do
    integer_primary_key :id

    attribute :device_id, :string do
      public? true
      description "The Astarte device ID of the device."
      allow_nil? false
    end

    attribute :name, :string do
      public? true
      description "The display name of the device."
      allow_nil? false
    end

    attribute :online, :boolean do
      public? true
      description "Whether the device is connected or not to Astarte"
      allow_nil? false
      default false
    end

    attribute :last_connection, :utc_datetime do
      public? true
      description "The date at which the device last connected to Astarte."
    end

    attribute :last_disconnection, :utc_datetime do
      public? true
      description "The date at which the device last disconnected from Astarte."
    end

    attribute :serial_number, :string do
      public? true
      description "The serial number of the device."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :realm, Edgehog.Astarte.Realm do
      allow_nil? false
    end

    belongs_to :system_model_part_number, Edgehog.Devices.SystemModelPartNumber do
      attribute_type :string
      source_attribute :part_number
      destination_attribute :part_number
    end

    has_one :system_model, Edgehog.Devices.SystemModel do
      public? true
      description "The system model of the device"
      manual ManualRelationships.SystemModel
    end

    many_to_many :tags, Edgehog.Labeling.Tag do
      public? true
      description "The tags of the device"
      through Edgehog.Labeling.DeviceTag
    end

    has_many :device_groups, Edgehog.Groups.DeviceGroup do
      public? true
      description "The groups the device belongs to."
      writable? false
      manual ManualRelationships.DeviceGroups
    end

    has_many :ota_operations, Edgehog.OSManagement.OTAOperation do
      public? true
      description "The existing OTA operations for this device"
      writable? false
    end
  end

  calculations do
    calculate :appengine_client, :struct, Calculations.AppEngineClient do
      constraints instance_of: Astarte.Client.AppEngine
      filterable? false
    end

    calculate :available_images, {:array, Types.ImageStatus} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :available_images}
    end

    calculate :device_status, :struct, Calculations.DeviceStatus do
      constraints instance_of: Astarte.Device.DeviceStatus
      filterable? false
    end

    calculate :capabilities, {:array, Types.Capability} do
      public? true
      description "The capabilities that the device can support."
      allow_nil? false
      calculation Calculations.Capabilities
    end

    calculate :cellular_connection, {:array, Modem} do
      public? true
      calculation Calculations.CellularConnection
    end

    calculate :base_image, Types.BaseImage do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :base_image_info}
    end

    calculate :available_containers, {:array, Types.ContainerStatus} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :available_containers}
    end

    calculate :battery_status, {:array, BatterySlot} do
      public? true
      calculation Calculations.BatteryStatus
    end

    calculate :forwarder_sessions, {:array, :struct} do
      description "The existing forwarder sessions of the device."
      filterable? false
      calculation Calculations.ForwarderSessions
    end

    calculate :hardware_info, Types.HardwareInfo do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :hardware_info}
    end

    calculate :location, Edgehog.Geolocation.Location do
      description """
      Describes the place where the device is located.

      The field holds information about the device's address, which is
      estimated by means of Edgehog's geolocation modules and the data
      published by the device.
      """

      public? true
      filterable? false
      calculation Calculations.Location
    end

    calculate :network_interfaces, {:array, NetworkInterface} do
      public? true
      calculation Calculations.NetworkInterfaces
    end

    calculate :os_info, Types.OSInfo do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :os_info}
    end

    calculate :position, Edgehog.Geolocation.Position do
      description """
      Describes the position of a device.

      The field holds information about the GPS coordinates of the device,
      which are estimated by means of Edgehog's geolocation modules and the
      data published by the device.
      """

      public? true
      filterable? false
      calculation Calculations.Position
    end

    calculate :runtime_info, Types.RuntimeInfo do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :runtime_info}
    end

    calculate :storage_usage, {:array, Types.StorageUnit} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :storage_usage}
    end

    calculate :system_status, Types.SystemStatus do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :system_status}
    end

    calculate :wifi_scan_results, {:array, Types.WiFiScanResult} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :wifi_scan_result}
    end

    # The following Astarte values don't have a custom type because they're not exposed via GraphQL
    # but they're used to synthesize other values
    calculate :modem_properties, {:array, :struct} do
      constraints items: [instance_of: Edgehog.Astarte.Device.CellularConnection.ModemProperties]
      calculation {Calculations.AstarteInterfaceValue, value_id: :modem_properties}
    end

    calculate :modem_status, {:array, :struct} do
      constraints items: [instance_of: Edgehog.Astarte.Device.CellularConnection.ModemStatus]
      calculation {Calculations.AstarteInterfaceValue, value_id: :modem_status}
    end

    calculate :sensor_positions, {:array, :struct} do
      constraints items: [instance_of: Edgehog.Astarte.Device.Geolocation.SensorPosition]
      filterable? false
      calculation Calculations.SensorPositions
    end
  end

  identities do
    identity :unique_realm_device_id, [:device_id, :realm_id]
  end

  postgres do
    table "devices"
    repo Edgehog.Repo

    references do
      reference :realm,
        index?: true,
        on_delete: :nothing,
        match_with: [tenant_id: :tenant_id],
        match_type: :full

      # We don't generate a foreign key for the system model part number since we want the device
      # to be able to declare its part number even _before_ we add the relative system model to
      # Edgehog
      reference :system_model_part_number, ignore?: true
    end
  end
end
