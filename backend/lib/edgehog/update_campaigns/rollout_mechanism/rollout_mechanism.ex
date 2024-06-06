#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.RolloutMechanism do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      storage: :map_with_tag,
      types: [
        push: [
          tag: :type,
          tag_value: :push,
          type: Edgehog.UpdateCampaigns.RolloutMechanism.PushRollout,
          cast_tag?: true
        ]
      ]
    ]

  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_type(_), do: :rollout_mechanism

  @impl AshGraphql.Type
  def graphql_unnested_unions(_constraints), do: [:push]
end
