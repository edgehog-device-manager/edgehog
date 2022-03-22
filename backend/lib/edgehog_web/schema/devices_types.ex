#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

  @desc """
  Denotes a type of hardware that devices can have.

  It refers to the physical components embedded in a device.
  This can represent, e.g., multiple revisions of a PCB (each with a \
  different part number) which are functionally equivalent from the device \
  point of view.
  """
  node object(:hardware_type) do
    @desc "The display name of the hardware type."
    field :name, non_null(:string)

    @desc "The identifier of the hardware type."
    field :handle, non_null(:string)

    @desc "The list of part numbers associated with the hardware type."
    field :part_numbers, non_null(list_of(non_null(:string))) do
      resolve &Resolvers.Devices.extract_hardware_type_part_numbers/3
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
    field :description, :localized_text do
      resolve &Resolvers.Devices.extract_localized_description/3
    end
  end

  object :devices_queries do
    @desc "Fetches the list of all hardware types."
    field :hardware_types, non_null(list_of(non_null(:hardware_type))) do
      resolve &Resolvers.Devices.list_hardware_types/3
    end

    @desc "Fetches a single hardware type."
    field :hardware_type, :hardware_type do
      @desc "The ID of the hardware type."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :hardware_type
      resolve &Resolvers.Devices.find_hardware_type/2
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
    @desc "Creates a new hardware type."
    payload field :create_hardware_type do
      input do
        @desc "The display name of the hardware type."
        field :name, non_null(:string)

        @desc """
        The identifier of the hardware type.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, non_null(:string)

        @desc "The list of part numbers associated with the hardware type."
        field :part_numbers, non_null(list_of(non_null(:string)))
      end

      output do
        @desc "The created hardware type."
        field :hardware_type, non_null(:hardware_type)
      end

      resolve &Resolvers.Devices.create_hardware_type/3
    end

    @desc "Updates a hardware type."
    payload field :update_hardware_type do
      input do
        @desc "The ID of the hardware type to be updated."
        field :hardware_type_id, non_null(:id)

        @desc "The display name of the hardware type."
        field :name, :string

        @desc """
        The identifier of the hardware type.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, :string

        @desc "The list of part numbers associated with the hardware type."
        field :part_numbers, list_of(non_null(:string))
      end

      output do
        @desc "The updated hardware type."
        field :hardware_type, non_null(:hardware_type)
      end

      middleware Absinthe.Relay.Node.ParseIDs, hardware_type_id: :hardware_type
      resolve &Resolvers.Devices.update_hardware_type/3
    end

    @desc "Deletes a hardware type."
    payload field :delete_hardware_type do
      input do
        @desc "The ID of the hardware type to be deleted."
        field :hardware_type_id, non_null(:id)
      end

      output do
        @desc "The deleted hardware type."
        field :hardware_type, non_null(:hardware_type)
      end

      middleware Absinthe.Relay.Node.ParseIDs, hardware_type_id: :hardware_type
      resolve &Resolvers.Devices.delete_hardware_type/2
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
