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

  input_object :hardware_type_input do
    field :name, non_null(:string)
    field :handle, non_null(:string)
    field :part_numbers, non_null(list_of(non_null(:string)))
  end

  node object(:hardware_type) do
    field :name, non_null(:string)
    field :handle, non_null(:string)

    field :part_numbers, non_null(list_of(non_null(:string))) do
      resolve &Resolvers.Appliances.extract_hardware_type_part_numbers/3
    end
  end

  object :appliances_queries do
    field :hardware_types, non_null(list_of(non_null(:hardware_type))) do
      resolve &Resolvers.Appliances.list_hardware_types/3
    end

    field :hardware_type, :hardware_type do
      arg :id, non_null(:id)
      middleware Absinthe.Relay.Node.ParseIDs, id: :hardware_type
      resolve &Resolvers.Appliances.find_hardware_type/2
    end
  end

  object :appliances_mutations do
    payload field :create_hardware_type do
      input do
        field :hardware_type, non_null(:hardware_type_input)
      end

      output do
        field :hardware_type, non_null(:hardware_type)
      end

      resolve &Resolvers.Appliances.create_hardware_type/3
    end

    payload field :update_hardware_type do
      input do
        field :id, non_null(:id)
        field :hardware_type, non_null(:hardware_type_input)
      end

      output do
        field :hardware_type, non_null(:hardware_type)
      end

      middleware Absinthe.Relay.Node.ParseIDs, id: :hardware_type
      resolve &Resolvers.Appliances.update_hardware_type/3
    end
  end
end
