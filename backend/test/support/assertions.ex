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

defmodule Edgehog.Assertions do
  @moduledoc """
  Assertions to help elixir tests
  """
  import ExUnit.Assertions

  defmacro assert_created(created_data, push) do
    quote do
      assert %{
               result: %{
                 data: %{
                   "deviceChanged" => %{
                     "created" => var!(unquote(created_data)),
                     "updated" => nil
                   }
                 }
               }
             } = var!(unquote(push))
    end
  end

  defmacro assert_updated(updated_data, push) do
    quote do
      assert %{
               result: %{
                 data: %{
                   "deviceChanged" => %{
                     "created" => nil,
                     "updated" => var!(unquote(updated_data))
                   }
                 }
               }
             } = var!(unquote(push))
    end
  end
end
