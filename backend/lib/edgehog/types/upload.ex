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

defmodule Edgehog.Types.Upload do
  @moduledoc false
  use Ash.Type
  use AshGraphql.Type

  @impl AshGraphql.Type
  def graphql_input_type(_), do: :upload

  @impl Ash.Type
  def storage_type(_), do: :term

  @impl Ash.Type
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(%Plug.Upload{} = value, _), do: {:ok, value}
  def cast_input(_, _), do: :error

  @impl Ash.Type
  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(%Plug.Upload{} = value, _), do: {:ok, value}
  def cast_stored(_, _), do: :error

  @impl Ash.Type
  def dump_to_native(nil, _), do: {:ok, nil}
  def dump_to_native(_, _), do: :error
end
