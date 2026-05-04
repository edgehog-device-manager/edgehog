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

defmodule Edgehog.Auth.Providers.NoneTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Edgehog.Auth.Providers.None
  alias Edgehog.TupleFixtures

  describe "init_context/1" do
    test "inits an empty context" do
      args = %{whatever: :arg}

      assert {:ok, []} = None.init_context(args)
    end
  end

  describe "check/2" do
    setup do
      ctx = None.init_context(nil)

      {:ok, %{context: ctx}}
    end

    test "authz every tuple", %{context: context} do
      tuple = TupleFixtures.tuple()

      assert {:ok, true} = None.check(tuple, context)
    end
  end

  describe "list_objects/2" do
    setup do
      ctx = None.init_context(nil)

      {:ok, %{context: ctx}}
    end

    test "lists all objects", %{context: context} do
      # Actual tuple should not even matter, it should just answer: {:ok, :all}
      tuple = TupleFixtures.tuple()

      assert {:ok, :all} = None.list_objects(tuple, context)
    end
  end

  describe "stream_list_objects/2" do
    setup do
      ctx = None.init_context(nil)

      {:ok, %{context: ctx}}
    end

    test "lists all objects", %{context: context} do
      # Actual tuple should not even matter, it should just answer: {:ok, :all}
      tuple = TupleFixtures.tuple()

      assert {:ok, :all} = None.stream_list_objects(tuple, context)
    end
  end
end
