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

defmodule Edgehog.Containers.Types.DeploymentConfig do
  @moduledoc """
  A deployment configuration map.
  """

  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        container_id: [
          type: :uuid,
          allow_nil?: false
        ],
        env: [
          type: {:array, Edgehog.Containers.Container.Types.EnvVar},
          allow_nil?: true
        ],
        env_strategy: [
          type: :atom,
          constraints: [
            one_of: [:merge, :override]
          ],
          allow_nil?: true
        ],
        file_binds: [
          type: {:array, Edgehog.Containers.Types.FileBind},
          allow_nil?: true
        ]
      ]
    ]

  @impl AshGraphql.Type
  def graphql_input_type(_), do: :deployment_config_spec_input

  @impl AshGraphql.Type
  def graphql_type(_), do: :deployment_config_spec
end
