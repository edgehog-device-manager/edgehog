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

  - type               :: instructs the extension about the FGA type of the resource (the corresponding type for resource that is defined in the model used by the provider)
  - id      (optional) :: instructs the extension on which attribute to use as resource id in the provider.
  - exclude (optional) :: sometimes we don't want to expose some relationships. These can be excluded from the provider flow trough this option

  ## Example 

  ```elixir

  fga do
    type :device                            # The FGA provider will use `device` as type for this resource in tuples
    id  :device_id                          # The `device_id` atrtibute will be used as `id` in tuples
    exclude [:system_model_part_number]     # The `system_model_part_number` relationship will not be considered when writing tuples
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
      ]
    ],
    entities: [@exclude]
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
    Extension.get_entities(dsl_state, [:fga])
  end
end

defmodule Ash.FGA.ExcludeTarget do
  @moduledoc """
  Utility module, represents an excluded relationship target
  """

  defstruct [:relationships, :__spark_metadata__]

  @type t :: %__MODULE__{
          relationships: list(),
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }
end
