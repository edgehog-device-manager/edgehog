#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateNetworkTest do
  @moduledoc false

  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  describe "createNetwork mutation" do
    test "create network with valid data", %{tenant: tenant} do
      label = unique_network_label()

      network =
        [tenant: tenant, label: label]
        |> create_network_mutation()
        |> extract_result!()

      assert network["label"] == label
    end
  end

  def create_network_mutation(opts) do
    default_document = """
    mutation CreateNetwork($input: CreateNetworkInput!) {
      createNetwork(input: $input) {
        result {
          label
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    default_input = %{
      "label" => Keyword.get(opts, :label, unique_network_label()),
      "driver" => Keyword.get(opts, :driver, "local")
    }

    input = Keyword.get(opts, :input, default_input)

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createNetwork" => %{
                 "result" => network
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert network != nil

    network
  end
end
