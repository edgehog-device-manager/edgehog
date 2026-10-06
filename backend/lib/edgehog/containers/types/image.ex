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

  When `image_credentials_id` is not provided, it defaults to `nil`
  (rather than being omitted). The `Container` `:create_and_relate` action
  looks images up through the `:reference_credentials` identity, and Ash
  only attempts that lookup when every identity key is present in the
  input — an absent key silently creates a duplicate image instead of
  relating the existing credential-less one.
  """

  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        reference: [
          type: :string,
          allow_nil?: false
        ],
        image_credentials_id: [
          type: :uuid,
          allow_nil?: true
        ]
      ]
    ]

  @impl Ash.Type
  def apply_constraints(%{} = value, constraints) do
    value =
      if Map.has_key?(value, :image_credentials_id),
        do: value,
        else: Map.put(value, :image_credentials_id, nil)

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
