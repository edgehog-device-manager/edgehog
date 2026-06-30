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

defmodule Ash.FGA.Transformers.UserOwner do
  @moduledoc """
  An Ash extension transformer that adds changes to write and delete FGA tuples
  between a resource and the user that created it with the `owner` relationship
  """

  use Spark.Dsl.Transformer

  alias Ash.FGA.Info
  alias Ash.Resource.Builder
  alias Edgehog.Auth.Changes

  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    if Info.ownership?(dsl_state) do
      type = Info.type(dsl_state)

      # TODO: possible Ash bug: `Ash.Resource.Info.primary_key` returns `[]` at compile time
      [primary_key_attr] =
        dsl_state
        |> Ash.Resource.Info.attributes()
        |> Enum.filter(& &1.primary_key?)
        |> Enum.map(& &1.name)

      write_change = {
        Changes.WriteOwner,
        fga_type: type, primary_key: primary_key_attr
      }

      erase_change = {
        Changes.EraseOwner,
        fga_type: type, primary_key: primary_key_attr
      }

      with {:ok, dsl_state} <- Builder.add_change(dsl_state, write_change, on: [:create]) do
        Builder.add_change(dsl_state, erase_change, on: [:destroy])
      end
    else
      :ok
    end
  end
end
