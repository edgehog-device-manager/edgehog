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

defmodule Edgehog.Containers.Types.FileMount do
  @moduledoc """
  Input type to represent a file mount.

  A file mount describes how a single file should be mounted inside a
  container: the path at which it should appear (`mountpoint`), whether
  the container requires it to be present in order to start (`required`),
  and, optionally, the file that should be used to populate it by default
  (`default_file_id`).
  """

  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        mountpoint: [
          type: :string,
          allow_nil?: false
        ],
        required: [
          type: :boolean,
          allow_nil?: true
        ],
        default_file_id: [
          type: :uuid,
          allow_nil?: true
        ]
      ]
    ]

  @impl AshGraphql.Type
  def graphql_input_type(_), do: :file_mount_desc_input

  @impl AshGraphql.Type
  def graphql_type(_), do: :file_mount_desc
end
