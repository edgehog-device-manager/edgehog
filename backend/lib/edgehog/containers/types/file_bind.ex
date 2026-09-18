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

defmodule Edgehog.Containers.Types.FileBind do
  @moduledoc """
  Input type to represent a file bind.
  """

  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        device_file_id: [
          type: :uuid
        ],
        file_download_request_id: [
          type: :uuid
        ],
        file_mount_id: [
          type: :uuid
        ]
      ]
    ]

  @required_keys [:file_download_request_id, :device_file_id]

  @impl Ash.Type
  def apply_constraints(value, constraints) do
    with {:ok, value} <- super(value, constraints) do
      required_keys? = Enum.any?(@required_keys, &Map.get(value, &1))

      cond do
        value in [nil, %{}] ->
          {:ok, value}

        required_keys? ->
          {:ok, value}

        true ->
          {:error,
           message:
             "at least one of file_url, file_download_request_id or device_file_id must be set"}
      end
    end
  end

  @impl AshGraphql.Type
  def graphql_input_type(_), do: :file_bind_spec_input

  @impl AshGraphql.Type
  def graphql_type(_), do: :file_bind_spec
end
