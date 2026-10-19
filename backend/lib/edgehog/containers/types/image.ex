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

defmodule Edgehog.Containers.Types.Image do
  @moduledoc """
  Input type representing an image.

  When optional segment fields or `image_credentials_id` are not provided, they
  default to `nil` (rather than being omitted). The `Container`
  `:create_and_relate` and `:update` actions look images up through the
  `:reference_credentials` identity, and Ash only attempts that lookup when
  every identity key is present in the input. Absent keys silently create a
  duplicate image instead of relating the existing one.
  """

  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        registry_host: [type: :string],
        registry_port: [type: :integer],
        repository: [type: :string],
        image: [type: :string, allow_nil?: false],
        tag: [type: :string],
        digest: [type: :string],
        image_credentials_id: [
          type: :uuid,
          allow_nil?: true
        ],
        pull_policy: [
          type: Edgehog.Containers.Types.PullPolicy,
          allow_nil?: true
        ]
      ]
    ]

  @optional_fields [
    :registry_host,
    :registry_port,
    :repository,
    :tag,
    :digest,
    :image_credentials_id
  ]

  @impl Ash.Type
  def apply_constraints(%{} = value, constraints) do
    value =
      Enum.reduce(@optional_fields, value, fn field, acc ->
        Map.put_new(acc, field, nil)
      end)

    super(value, constraints)
  end

  @impl Ash.Type
  def apply_constraints(value, constraints) do
    super(value, constraints)
  end

  @impl AshGraphql.Type
  def graphql_input_type(_), do: :image_desc_input

  @impl AshGraphql.Type
  def graphql_type(_), do: :image_desc
end
