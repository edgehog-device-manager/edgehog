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

defmodule EdgehogWeb.Schema.Mutation.CreateAllowedRegistryTest do
  @moduledoc false

  use EdgehogWeb.GraphqlCase, async: true

  describe "createAllowedRegistry mutation" do
    test "create allowed registry with valid data", %{tenant: tenant} do
      registry = "registry-#{System.unique_integer([:positive])}.example.com"

      document = """
      mutation CreateAllowedRegistry($input: CreateAllowedRegistryInput!) {
        createAllowedRegistry(input: $input) {
          result {
            registry
          }
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"input" => %{"registry" => registry}},
          context: %{tenant: tenant, actor: %{}}
        )

      assert %{
               data: %{
                 "createAllowedRegistry" => %{
                   "result" => %{"registry" => ^registry}
                 }
               }
             } = result

      refute :errors in Map.keys(result)
    end

    test "fails with invalid registry IPv4", %{tenant: tenant} do
      registry = "256.256.256.256"

      document = """
      mutation CreateAllowedRegistry($input: CreateAllowedRegistryInput!) {
        createAllowedRegistry(input: $input) {
          result {
            registry
          }
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"input" => %{"registry" => registry}},
          context: %{tenant: tenant, actor: %{}}
        )

      assert %{
               data: %{
                 "createAllowedRegistry" => nil
               },
               errors: _errors
             } = result
    end

    test "fails with invalid registry IPv6", %{tenant: tenant} do
      registry = "2001:db8:::1"

      document = """
      mutation CreateAllowedRegistry($input: CreateAllowedRegistryInput!) {
        createAllowedRegistry(input: $input) {
          result {
            registry
          }
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"input" => %{"registry" => registry}},
          context: %{tenant: tenant, actor: %{}}
        )

      assert %{
               data: %{
                 "createAllowedRegistry" => nil
               },
               errors: _errors
             } = result
    end

    test "fails with invalid registry host", %{tenant: tenant} do
      registry = "invalid_registry"

      document = """
      mutation CreateAllowedRegistry($input: CreateAllowedRegistryInput!) {
        createAllowedRegistry(input: $input) {
          result {
            registry
          }
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"input" => %{"registry" => registry}},
          context: %{tenant: tenant, actor: %{}}
        )

      assert %{
               data: %{
                 "createAllowedRegistry" => nil
               },
               errors: _errors
             } = result
    end
  end
end
