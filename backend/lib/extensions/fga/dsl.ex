#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Ash.FGA do
  @moduledoc """
  An ash FGA plugin.

  This extension adds an entry for fga types and relations:

  - type                  :: instructs the extension about the FGA type of the resource (the corresponding type for resource that is defined in the model used by the provider)
  - id         (optional) :: instructs the extension on which attribute to use as resource id in the provider.
  - exclude    (optional) :: sometimes we don't want to expose some relationships. These can be excluded from the provider flow trough this option
  - ownership? (optional) :: resource has a `owner` relationship with the user. Default: `true`

  ## Example 

  ```elixir

  fga do
    type :device                            # The FGA provider will use `device` as type for this resource in tuples
    id  :device_id                          # The `device_id` atrtibute will be used as `id` in tuples
    exclude [:system_model_part_number]     # The `system_model_part_number` relationship will not be considered when writing tuples
    ownership? true                         # Creating a device is an operation performed by a user, so it has an owner
  end
  ```
  """

  alias Ash.FGA.Transformers

  @exclude %Spark.Dsl.Entity{
    name: :exclude,
    target: Ash.FGA.ExcludeTarget,
    args: [:relationships],
    schema: [
      relationships: [
        type: {:list, :atom},
        required: false,
        doc: "The FGA exclude that represents elements of this resource."
      ]
    ]
  }

  @capabilities %Spark.Dsl.Entity{
    name: :capabilities,
    target: Ash.FGA.CapabilitiesTarget,
    # args: [],
    # imports: [Ash.Policy.Check.Builtins, Ash.Expr],
    schema: [
      view: [
        type: :boolean,
        required: false,
        default: true,
        doc: "Should be true if the resource has a `can_view` relationship defined in the model"
      ],
      edit: [
        type: :boolean,
        required: false,
        default: true,
        doc: "Should be true if the resource has a `can_edit` relationship defined in the model"
      ],
      delete: [
        type: :boolean,
        required: false,
        default: true,
        doc: "Should be true if the resource has a `can_delete` relationship defined in the model"
      ],
      operations: [
        type: {:list, :atom},
        required: false,
        default: [],
        doc:
          "A list of the extra operations that have a corresponding relationship defined in the model.
        For example, editing a device's tags, defined in the capability `can_edit_tags`, is represented with the atom `:edit_tags`"
      ]
    ]
  }

  @fga %Spark.Dsl.Section{
    name: :fga,
    describe: """
    Configures the interactions with the FGA Service.
    """,
    schema: [
      type: [
        type: :atom,
        required: true,
        doc: "The FGA type that represents elements of this resource."
      ],
      id: [
        type: :atom,
        doc: "The FGA id that represents elements of this resource."
      ],
      ownership?: [
        type: :boolean,
        doc:
          "Whether or not the resource has a `owner` relationship with the `user` type in the model.",
        default: true
      ]
    ],
    entities: [@exclude, @capabilities]
  }

  # credo:disable-for-next-line
  use Spark.Dsl.Extension,
    transformers: [Transformers.Alias, Transformers.UserOwner, Transformers.WriteRels],
    sections: [@fga]
end

defmodule Ash.FGA.Info do
  @moduledoc """
  Utility functions.

  They can return various information about the `fga` configuration section of a resource.
  """

  use Spark.InfoGenerator, extension: Ash.FGA, sections: [@fga]
  alias Spark.Dsl.Extension

  def id(dsl_state) do
    Extension.get_opt(dsl_state, [:fga], :id, :id)
  end

  def type(dsl_state) do
    Extension.get_opt(dsl_state, [:fga], :type)
  end

  def exclude(dsl_state) do
    dsl_state
    |> Extension.get_entities([:fga])
    |> Enum.filter(&(&1.__struct__ == Ash.FGA.ExcludeTarget))
  end

  def ownership?(dsl_state) do
    Extension.get_opt(dsl_state, [:fga], :ownership?, true)
  end

  def capabilities(dsl_state) do
    dsl_state =
      dsl_state
      |> Extension.get_entities([:fga])
      |> Enum.filter(&(&1.__struct__ == Ash.FGA.CapabilitiesTarget))

    case dsl_state do
      [] -> %{}
      [capabilities] -> capabilities
    end
  end

  def can_view?(dsl_state) do
    dsl_state
    |> capabilities()
    |> Map.get(:view, true)
  end

  def can_edit?(dsl_state) do
    dsl_state
    |> capabilities()
    |> Map.get(:edit, true)
  end

  def can_delete?(dsl_state) do
    dsl_state
    |> capabilities()
    |> Map.get(:delete, true)
  end

  def operations(dsl_state) do
    dsl_state
    |> capabilities()
    |> Map.get(:operations, [])
  end
end

defmodule Ash.FGA.ExcludeTarget do
  @moduledoc """
  Utility module, represents an excluded relationship target
  """

  defstruct [:relationships, :__spark_metadata__]

  @type t :: %__MODULE__{
          relationships: list(atom()),
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }
end

defmodule Ash.FGA.CapabilitiesTarget do
  @moduledoc """
  Utility module, represents the capabilities supported by the model
  """
  defstruct [:view, :edit, :delete, :operations, :__spark_metadata__]

  @type t :: %__MODULE__{
          view: boolean(),
          edit: boolean(),
          delete: boolean(),
          operations: list(atom()),
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }
end
