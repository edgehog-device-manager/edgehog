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

defmodule EdgehogWeb.Schema.AppliancesTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Resolvers

  @desc """
  Denotes a type of hardware that devices can have.

  It refers to the physical components embedded in an appliance.
  This can represent, e.g., multiple revisions of a PCB (each with a \
  different part number) which are functionally equivalent from the appliance \
  point of view.
  """
  node object(:hardware_type) do
    @desc "The display name of the hardware type."
    field :name, non_null(:string)

    @desc "The identifier of the hardware type."
    field :handle, non_null(:string)

    @desc "The list of part numbers associated with the hardware type."
    field :part_numbers, non_null(list_of(non_null(:string))) do
      resolve &Resolvers.Appliances.extract_hardware_type_part_numbers/3
    end
  end

  @desc """
  Represents a specific appliance model.

  An appliance model corresponds to what the users thinks as functionally \
  equivalent appliances (e.g. two revisions of an appliance containing two \
  different embedded chips but that have the same enclosure and the same \
  functionality).
  Each ApplianceModel must be associated to a specific HardwareType.
  """
  node object(:appliance_model) do
    @desc "The display name of the appliance model."
    field :name, non_null(:string)

    @desc "The identifier of the appliance model."
    field :handle, non_null(:string)

    @desc "The type of hardware that can be plugged into the appliance model."
    field :hardware_type, non_null(:hardware_type)

    @desc "The list of part numbers associated with the appliance model."
    field :part_numbers, non_null(list_of(non_null(:string))) do
      resolve &Resolvers.Appliances.extract_appliance_model_part_numbers/3
    end

    @desc """
    A localized description of the appliance model.
    The language of the description can be controlled passing an \
    Accept-Language header in the request. If no such header is present, the \
    default tenant language is returned.
    """
    field :description, :localized_text
  end

  object :appliances_queries do
    @desc "Fetches the list of all hardware types."
    field :hardware_types, non_null(list_of(non_null(:hardware_type))) do
      resolve &Resolvers.Appliances.list_hardware_types/3
    end

    @desc "Fetches a single hardware type."
    field :hardware_type, :hardware_type do
      @desc "The ID of the hardware type."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :hardware_type
      resolve &Resolvers.Appliances.find_hardware_type/2
    end

    @desc "Fetches the list of all appliance models."
    field :appliance_models, non_null(list_of(non_null(:appliance_model))) do
      resolve &Resolvers.Appliances.list_appliance_models/3
    end

    @desc "Fetches a single appliance model."
    field :appliance_model, :appliance_model do
      @desc "The ID of the appliance model."
      arg :id, non_null(:id)

      middleware Absinthe.Relay.Node.ParseIDs, id: :appliance_model
      resolve &Resolvers.Appliances.find_appliance_model/2
    end
  end

  object :appliances_mutations do
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

      resolve &Resolvers.Appliances.create_hardware_type/3
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
      resolve &Resolvers.Appliances.update_hardware_type/3
    end

    @desc "Creates a new appliance model."
    payload field :create_appliance_model do
      input do
        @desc "The display name of the appliance model."
        field :name, non_null(:string)

        @desc """
        The identifier of the appliance model.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, non_null(:string)

        @desc "The list of part numbers associated with the appliance model."
        field :part_numbers, non_null(list_of(non_null(:string)))

        @desc """
        The ID of the hardware type that can be plugged into the appliance \
        model.
        """
        field :hardware_type_id, non_null(:id)

        @desc """
        An optional localized description. This description can only use the \
        default tenant locale.
        """
        field :description, :localized_text_input
      end

      output do
        @desc "The created appliance model."
        field :appliance_model, non_null(:appliance_model)
      end

      middleware Absinthe.Relay.Node.ParseIDs, hardware_type_id: :hardware_type

      resolve &Resolvers.Appliances.create_appliance_model/3
    end

    @desc "Updates an appliance model."
    payload field :update_appliance_model do
      input do
        @desc "The ID of the appliance model to be updated."
        field :appliance_model_id, non_null(:id)

        @desc "The display name of the appliance model."
        field :name, :string

        @desc """
        The identifier of the appliance model.

        It should start with a lower case ASCII letter and only contain \
        lower case ASCII letters, digits and the hyphen - symbol.
        """
        field :handle, :string

        @desc "The list of part numbers associated with the appliance model."
        field :part_numbers, list_of(non_null(:string))

        @desc """
        An optional localized description. This description can only use the \
        default tenant locale.
        """
        field :description, :localized_text_input
      end

      output do
        @desc "The updated appliance model."
        field :appliance_model, non_null(:appliance_model)
      end

      middleware Absinthe.Relay.Node.ParseIDs,
        appliance_model_id: :appliance_model,
        hardware_type_id: :hardware_type

      resolve &Resolvers.Appliances.update_appliance_model/3
    end
  end
end
