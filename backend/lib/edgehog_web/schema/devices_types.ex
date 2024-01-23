#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.DevicesTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Resolvers
  alias EdgehogWeb.Middleware

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
    A string to match against the part number of the device's system model.
    The match is case-insensitive and tests whether the string is included in \
    the part number of the device's system model.
    """
    field :system_model_part_number, :string

    @desc """
    A string to match against the handle of the device's system model.
    The match is case-insensitive and tests whether the string is included in \
    the handle of the device's system model.
    """
    field :system_model_handle, :string

    @desc """
    A string to match against the name of the device's system model.
    The match is case-insensitive and tests whether the string is included in \
    the name of the device's system model.
    """
    field :system_model_name, :string

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

    @desc """
    A string to match against the tags of the device.
    The match is case-insensitive and tests whether the string is included in \
    one of the tags of the device.
    """
    field :tag, :string
  end

  @desc """
  An input object for a device attribute.
  """
  input_object :device_attribute_input do
    @desc "The namespace of the device attribute."
    field :namespace, non_null(:device_attribute_namespace)

    @desc "The key of the device attribute."
    field :key, non_null(:string)

    @desc "The type of the device attribute."
    field :type, non_null(:variant_type)

    @desc "The value of the device attribute."
    field :value, non_null(:variant_value)
  end

  @desc "The possible namespace values for device attributes"
  enum :device_attribute_namespace do
    @desc "Custom attributes, user defined"
    value :custom
  end

  object :device_attribute do
    @desc "The namespace of the device attribute."
    field :namespace, non_null(:device_attribute_namespace)

    @desc "The key of the device attribute."
    field :key, non_null(:string)

    @desc "The type of the device attribute."
    field :type, non_null(:variant_type) do
      resolve &Resolvers.Devices.extract_attribute_type/3
    end

    @desc "The value of the device attribute."
    field :value, non_null(:variant_value) do
      resolve &Resolvers.Devices.extract_attribute_value/3
    end
  end

  @desc """
  Denotes a device instance that connects and exchanges data.

  Each Device is associated to a specific SystemModel, which in turn is \
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

    @desc "The system model of the device."
    field :system_model, :system_model

    @desc "The device groups the device belongs to."
    field :device_groups, non_null(list_of(non_null(:device_group))) do
      resolve &Resolvers.Groups.batched_groups_for_device/3
    end

    @desc "The tags of the device"
    field :tags, non_null(list_of(non_null(:string))) do
      resolve &Resolvers.Devices.extract_device_tags/3
    end

    @desc "The custom attributes of the device. These attributes are user editable."
    field :custom_attributes, non_null(list_of(non_null(:device_attribute)))

    @desc "List of capabilities supported by the device."
    field :capabilities, non_null(list_of(non_null(:device_capability))) do
      resolve &Resolvers.Capabilities.list_device_capabilities/3
      middleware Middleware.ErrorHandler
    end

    @desc "Info read from the device's hardware."
    field :hardware_info, :hardware_info do
      resolve &Resolvers.Astarte.fetch_hardware_info/3
      middleware Middleware.ErrorHandler
    end

    @desc "The estimated location of the device."
    field :location, :device_location do
      resolve &Resolvers.Geolocation.fetch_device_location/3
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

    @desc "Information about the operating system's base image for the device."
    field :base_image, :base_image_info do
      resolve &Resolvers.Astarte.fetch_base_image/3
      middleware Middleware.ErrorHandler
    end

    @desc "Information about the operating system of the device."
    field :os_info, :os_info do
      resolve &Resolvers.Astarte.fetch_os_info/3
      middleware Middleware.ErrorHandler
    end

    @desc "The existing OTA operations for this device"
    field :ota_operations, non_null(list_of(non_null(:ota_operation))) do
      # TODO: this causes an N+1 if used on the device list, we should use dataloader instead
      resolve &Resolvers.OSManagement.ota_operations_for_device/3
    end

    @desc "The status of cellular connection of the device."
    field :cellular_connection, list_of(non_null(:modem)) do
      resolve &Resolvers.Astarte.fetch_cellular_connection/3
      middleware Middleware.ErrorHandler
    end

    @desc "Information about the Edgehog runtime running on the device."
    field :runtime_info, :runtime_info do
      resolve &Resolvers.Astarte.fetch_runtime_info/3
      middleware Middleware.ErrorHandler
    end

    @desc "The list of Network Interfaces of the device."
    field :network_interfaces, list_of(non_null(:network_interface)) do
      resolve &Resolvers.Astarte.fetch_network_interfaces/3
      middleware Middleware.ErrorHandler
    end
  end

  @desc """
  Represents a specific system model.

  A system model corresponds to what the users thinks as functionally \
  equivalent devices (e.g. two revisions of a device containing two different \
  embedded chips but having the same enclosure and the same functionality).\
  Each SystemModel must be associated to a specific HardwareType.
  """
  node object(:system_model) do
    @desc "The display name of the system model."
    field :name, non_null(:string)

    @desc "The identifier of the system model."
    field :handle, non_null(:string)

    @desc "The URL of the related picture."
    field :picture_url, :string

    @desc "The type of hardware that can be plugged into the system model."
    field :hardware_type, non_null(:hardware_type)

    @desc "The list of part numbers associated with the system model."
    field :part_numbers, non_null(list_of(non_null(:string))) do
      resolve &Resolvers.Devices.extract_system_model_part_numbers/3
    end

    @desc """
    A localized description of the system model.
    The language of the description can be controlled passing an \
    Accept-Language header in the request. If no such header is present, the \
    default tenant language is returned.
    """
    field :description, :string do
      resolve &Resolvers.Devices.extract_localized_description/3
    end
  end

  object :devices_queries do
    @desc "Fetches the list of all devices."
    field :devices, non_null(list_of(non_null(:device))) do
      @desc "An optional set of filters to apply when fetching the devices."
      arg :filter, :device_filter
      resolve &Resolvers.Devices.list_devices/3
    end

    @desc "Fetches a single device."
    field :device, :device do
      @desc "The ID of the device."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :device
      resolve &Resolvers.Devices.find_device/2
    end

    @desc "Fetches the list of all system models."
    field :system_models, non_null(list_of(non_null(:system_model))) do
      resolve &Resolvers.Devices.list_system_models/3
    end

    @desc "Fetches a single system model."
    field :system_model, :system_model do
      @desc "The ID of the system model."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :system_model
      resolve &Resolvers.Devices.find_system_model/2
    end
  end

  object :devices_mutations do
    @desc "Updates a device."
    payload field :update_device do
      input do
        @desc "The GraphQL ID (not the Astarte Device ID) of the device to be updated."
        field :device_id, non_null(:id)

        @desc "The display name of the device."
        field :name, :string

        @desc "The tags of the device. These replace all the current tags."
        field :tags, list_of(non_null(:string))

        @desc "The custom attributes of the device. These replace all the current custom attributes."
        field :custom_attributes, list_of(non_null(:device_attribute_input))
      end

      output do
        @desc "The updated device."
        field :device, non_null(:device)
      end

      middleware Absinthe.Relay.Node.ParseIDs, device_id: :device
      resolve &Resolvers.Devices.update_device/2
    end

    @desc "Creates a new system model."
    payload field :create_system_model do
      input do
        @desc "The display name of the system model."
        field :name, non_null(:string)

        @desc """
        The identifier of the system model.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, non_null(:string)

        @desc """
        The file blob of a related picture.

        When this field is specified, the pictureUrl field is ignored.
        """
        field :picture_file, :upload

        @desc """
        The file URL of a related picture.

        Specifying a null value will remove the existing picture.
        When the pictureFile field is specified, this field is ignored.
        """
        field :picture_url, :string

        @desc "The list of part numbers associated with the system model."
        field :part_numbers, non_null(list_of(non_null(:string)))

        @desc """
        The ID of the hardware type that can be used by devices of this model.
        """
        field :hardware_type_id, non_null(:id)

        @desc """
        An optional localized description. This description can only use the \
        default tenant locale.
        """
        field :description, :localized_text_input
      end

      output do
        @desc "The created system model."
        field :system_model, non_null(:system_model)
      end

      middleware Absinthe.Relay.Node.ParseIDs, hardware_type_id: :hardware_type

      resolve &Resolvers.Devices.create_system_model/3
    end

    @desc "Updates a system model."
    payload field :update_system_model do
      input do
        @desc "The ID of the system model to be updated."
        field :system_model_id, non_null(:id)

        @desc "The display name of the system model."
        field :name, :string

        @desc """
        The identifier of the system model.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, :string

        @desc """
        The file blob of a related picture.

        When this field is specified, the pictureUrl field is ignored.
        """
        field :picture_file, :upload

        @desc """
        The file URL of a related picture.

        Specifying a null value will remove the existing picture.
        When the pictureFile field is specified, this field is ignored.
        """
        field :picture_url, :string

        @desc "The list of part numbers associated with the system model."
        field :part_numbers, list_of(non_null(:string))

        @desc """
        An optional localized description. This description can only use the \
        default tenant locale.
        """
        field :description, :localized_text_input
      end

      output do
        @desc "The updated system model."
        field :system_model, non_null(:system_model)
      end

      middleware Absinthe.Relay.Node.ParseIDs,
        system_model_id: :system_model,
        hardware_type_id: :hardware_type

      resolve &Resolvers.Devices.update_system_model/3
    end

    @desc "Deletes a system model."
    payload field :delete_system_model do
      input do
        @desc "The ID of the system model to be deleted."
        field :system_model_id, non_null(:id)
      end

      output do
        @desc "The deleted system model."
        field :system_model, non_null(:system_model)
      end

      middleware Absinthe.Relay.Node.ParseIDs, system_model_id: :system_model
      resolve &Resolvers.Devices.delete_system_model/2
    end
  end
end
