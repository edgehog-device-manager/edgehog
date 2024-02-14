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

    hide_fields [:tenant, :part_number_strings]

    queries do
      get :device, :get
      list :devices, :list
    end

    mutations do
      update :update_device, :update
    end
  end

  actions do
    defaults [:create, :destroy]

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
  end

  attributes do
    integer_primary_key :id

    attribute :device_id, :string do
      description "The Astarte device ID of the device."
      allow_nil? false
    end

    attribute :name, :string do
      description "The display name of the device."
      allow_nil? false
    end

    attribute :online, :boolean do
      description "Whether the device is connected or not to Astarte"
      allow_nil? false
      default false
    end

    attribute :last_connection, :utc_datetime do
      description "The date at which the device last connected to Astarte."
    end

    attribute :last_disconnection, :utc_datetime do
      description "The date at which the device last disconnected from Astarte."
    end

    attribute :serial_number, :string do
      description "The serial number of the device."
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :realm, Edgehog.Astarte.Realm do
      api Edgehog.Astarte
      attribute_writable? true
    end

    belongs_to :system_model_part_number, Edgehog.Devices.SystemModelPartNumber do
      attribute_type :string
      source_attribute :part_number
      destination_attribute :part_number
      attribute_writable? true
    end

    has_one :system_model, Edgehog.Devices.SystemModel do
      description "The system model of the device"
      manual ManualRelationships.SystemModel
    end
  end

  calculations do
    calculate :appengine_client, :struct, Calculations.AppEngineClient do
      constraints instance_of: Astarte.Client.AppEngine
      private? true
      filterable? false
    end

    calculate :os_info, Types.OSInfo do
      calculation {Calculations.AstarteInterfaceValue, value_id: :os_info}
    end

    calculate :wifi_scan_results, {:array, Types.WiFiScanResult} do
      calculation {Calculations.AstarteInterfaceValue, value_id: :wifi_scan_result}
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
