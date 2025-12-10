#
# This file is part of Edgehog.
#
# Copyright 2022-2025 SECO Mind Srl
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
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.DeviceMapping
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Volume
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

    # TODO: add :device_groups as a relay-paginated relationship. Since it's a
    # manual relationship, it needs to implement callbacks that define
    # datalayer subqueries so Ash can compose and support the functionality.
    paginate_relationship_with application_deployments: :relay,
                               ota_operations: :relay,
                               tags: :relay

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :device_created do
        action_types :create
      end

      subscribe :device_updated do
        action_types :update
      end
    end
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
      change Changes.SetupReconciler

      # Only if created
      change set_attribute(:device_id, arg(:device_id))
      change set_attribute(:name, arg(:device_id))

      # If updated or created
      change set_attribute(:online, true)
      change set_attribute(:last_connection, arg(:timestamp))
    end

    create :from_device_registered_event do
      upsert? true
      upsert_identity :unique_realm_device_id
      upsert_fields [:updated_at]

      accept [:realm_id]
      argument :device_id, :string, allow_nil?: false

      # Only if created
      change set_attribute(:device_id, arg(:device_id))
      change set_attribute(:name, arg(:device_id))
    end

    create :from_device_disconnected_event do
      upsert? true
      upsert_identity :unique_realm_device_id
      upsert_fields [:online, :last_disconnection, :updated_at]

      accept [:realm_id]
      argument :device_id, :string, allow_nil?: false
      argument :timestamp, :datetime, allow_nil?: false

      change Changes.InitializeFromDeviceStatus
      change Changes.TearDownReconciler

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

    update :send_create_deployment_request do
      description "Send a create deployment request to the device."

      argument :deployment, :struct do
        constraints instance_of: Deployment
        description "The Deployment the device has to instantiate."
        allow_nil? false
      end

      manual ManualActions.SendCreateDeployment
    end

    update :send_create_volume_request do
      description "Send a create volume request to the device."

      argument :volume, :struct do
        constraints instance_of: Volume
        description "The new volume for the device."
        allow_nil? false
      end

      argument :deployment, :struct do
        constraints instance_of: Deployment
        description "The deployment in which this volume is used"
        allow_nil? false
      end

      manual ManualActions.SendCreateVolume
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

      argument :deployment, :struct do
        constraints instance_of: Deployment
        description "The deployment in which this image is used"
        allow_nil? false
      end

      manual ManualActions.SendCreateImageRequest
    end

    update :send_create_container_request do
      description "Sends a create container request to the device."

      argument :container, :struct,
        constraints: [instance_of: Edgehog.Containers.Container],
        description: "The Container the device has to initiate.",
        allow_nil?: false

      argument :deployment, :struct do
        constraints instance_of: Deployment
        description "The deployment in which this container is used"
        allow_nil? false
      end

      manual ManualActions.SendCreateContainer
    end

    update :send_create_network_request do
      description "Sends a create network request to the device."

      argument :network, :struct,
        constraints: [instance_of: Edgehog.Containers.Network],
        description: "The Network the device has to create.",
        allow_nil?: false

      argument :deployment, :struct do
        constraints instance_of: Deployment
        description "The deployment in which this network is used"
        allow_nil? false
      end

      manual ManualActions.SendCreateNetwork
    end

    update :send_create_device_mapping_request do
      description "Send a create device-file mapping request to the device."

      argument :device_mapping, :struct do
        constraints instance_of: DeviceMapping
        description "The new device-file mapping for the device."
        allow_nil? false
      end

      argument :deployment, :struct do
        constraints instance_of: Deployment
        description "The deployment in which this device-file mapping is used."
        allow_nil? false
      end

      manual ManualActions.SendCreateDeviceMapping
    end

    update :send_release_command do
      description "Sends a command for the given application release."

      argument :release, :struct do
        constraints instance_of: Release
        description "The release target of the command."
      end

      argument :command, Edgehog.Devices.Device.DeploymentCommand

      manual Edgehog.Devices.Device.ManualActions.SendApplicationCommand
    end

    update :update_application do
      description "Updates an application to a newer release."

      argument :from, :struct do
        constraints instance_of: Deployment
        allow_nil? false

        description """
        The release to be upgraded. Should be currently installed.
        This argument is needed because there might be multiple versions of a single application installed on the device.
        """
      end

      argument :to, :struct do
        constraints instance_of: Deployment
        allow_nil? false
        description "The new release of the application"
      end

      manual Edgehog.Devices.Device.ManualActions.UpdateApplication
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
      attribute_public? true
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

    has_many :application_deployments, Deployment do
      public? true
    end

    has_many :container_deplomyents, Edgehog.Containers.Container.Deployment
    has_many :network_deplomyents, Edgehog.Containers.Network.Deployment
    has_many :volume_deplomyents, Edgehog.Containers.Volume.Deployment
    has_many :image_deplomyents, Edgehog.Containers.Image.Deployment
    has_many :device_mapping_deplomyents, Edgehog.Containers.DeviceMapping.Deployment

    many_to_many :application_releases, Release do
      through Deployment
      join_relationship :application_deployments
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

    calculate :available_volumes, {:array, Types.VolumeStatus} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :available_volumes}
    end

    calculate :available_networks, {:array, Types.NetworkStatus} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :available_networks}
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

    calculate :available_deployments, {:array, Types.DeploymentStatus} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :available_deployments}
    end

    calculate :base_image, Types.BaseImage do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :base_image_info}
    end

    calculate :available_containers, {:array, Types.ContainerStatus} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :available_containers}
    end

    calculate :available_device_mappings, {:array, Types.DeviceMappingStatus} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :available_device_mappings}
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
