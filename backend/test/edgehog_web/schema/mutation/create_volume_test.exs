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

defmodule EdgehogWeb.Schema.Mutation.CreateVolumeTest do
  @moduledoc false

  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  describe "createVolume mutation" do
    test "create volume with valid data", %{tenant: tenant} do
      label = unique_volume_label()

      volume =
        [tenant: tenant, label: label]
        |> create_volume_mutation()
        |> extract_result!()

      assert volume["label"] == label
    end

    test "create volume with invalid data throws error", %{tenant: tenant} do
      label = ""

      error =
        [tenant: tenant, label: label]
        |> create_volume_mutation()
        |> extract_error!()

      assert [:label] = error.fields
      assert "is required" == error.message
    end
  end

  def create_volume_mutation(opts) do
    default_document = """
    mutation CreateVolume($input: CreateVolumeInput!) {
      createVolume(input: $input) {
        result {
          label
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    default_input = %{
      "label" => Keyword.get(opts, :label, unique_volume_label()),
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
               "createVolume" => %{
                 "result" => volume
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert volume != nil

    volume
  end

  defp extract_error!(result) do
    assert %{
             data: %{"createVolume" => nil},
             errors: [error]
           } = result

    error
  end
end
