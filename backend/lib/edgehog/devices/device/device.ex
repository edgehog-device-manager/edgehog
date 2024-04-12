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
  use Edgehog.MultitenantResource,
    domain: Edgehog.Devices,
    extensions: [
      AshGraphql.Resource
    ]

  alias Edgehog.Devices.Device.Calculations
  alias Edgehog.Devices.Device.ManualRelationships
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

    queries do
      get :device, :get
      list :devices, :list
    end

    mutations do
      update :update_device, :update
      update :add_device_tags, :add_tags
      update :remove_device_tags, :remove_tags
    end
  end

  actions do
    defaults [:destroy]

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

    read :get do
      description "Returns a single device."
      get? true
    end

    read :list do
      description "Returns a list of devices."
      primary? true
    end

    update :update do
      description "Updates a device."

      accept [:name]
    end

    update :add_tags do
      description "Add tags to a device."
      require_atomic? false

      argument :tags, {:array, :string} do
        allow_nil? false
        constraints min_length: 1, items: [min_length: 1]
      end

      change {Edgehog.Changes.NormalizeTagName, argument: :tags}

      change manage_relationship(:tags,
               on_lookup: :relate,
               on_no_match: :create,
               value_is_key: :name,
               use_identities: [:name_tenant_id]
             )
    end

    update :remove_tags do
      description "Remove tags from a device."
      require_atomic? false

      argument :tags, {:array, :string} do
        allow_nil? false
        constraints min_length: 1, items: [min_length: 1]
      end

      change {Edgehog.Changes.NormalizeTagName, argument: :tags}

      change manage_relationship(:tags,
               on_match: :unrelate,
               on_no_match: :ignore,
               on_missing: :ignore,
               value_is_key: :name,
               use_identities: [:name_tenant_id]
             )
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
  end

  calculations do
    calculate :appengine_client, :struct, Calculations.AppEngineClient do
      constraints instance_of: Astarte.Client.AppEngine
      filterable? false
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

    calculate :cellular_connection, {:array, Types.Modem} do
      public? true
      calculation Calculations.CellularConnection
    end

    calculate :base_image, Types.BaseImage do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :base_image_info}
    end

    calculate :battery_status, {:array, Types.BatterySlot} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :battery_status}
    end

    calculate :hardware_info, Types.HardwareInfo do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :hardware_info}
    end

    calculate :network_interfaces, {:array, Types.NetworkInterface} do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :network_interfaces}
    end

    calculate :os_info, Types.OSInfo do
      public? true
      calculation {Calculations.AstarteInterfaceValue, value_id: :os_info}
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
  end

  identities do
    # These have to be named this way to match the existing unique indexes
    # we already have. Ash uses identities to add a `unique_constraint` to the
    # Ecto changeset, so names have to match. There's no need to explicitly add
    # :tenant_id in the fields because identity in a multitenant resource are
    # automatically scoped to a specific :tenant_id
    # TODO: change index names when we generate migrations at the end of the porting
    identity :device_id_realm_id_tenant_id, [:device_id, :realm_id]
  end

  postgres do
    table "devices"
    repo Edgehog.Repo
  end
end
