#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Container.Types.EnvVar do
  @moduledoc """
  The type used to specify environment variables in a key-value pair format
  """
  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        key: [
          type: :string,
          allow_nil?: false
        ],
        value: [
          type: :string,
          allow_nil?: false
        ]
      ]
    ]

  @impl Ash.Type
  def cast_stored(value, constraints) do
    %{"key" => key, "value" => value} = value
    cast_value = %{key: key, value: value}
    __MODULE__.subtype_of().cast_stored(cast_value, constraints)
  end

  @impl AshGraphql.Type
  def graphql_input_type(_), do: :container_env_var_input

  @impl AshGraphql.Type
  def graphql_type(_), do: :container_env_var
end
