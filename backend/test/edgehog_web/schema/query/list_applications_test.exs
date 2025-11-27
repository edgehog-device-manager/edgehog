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

defmodule EdgehogWeb.Schema.Query.ListApplicationsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  describe "applications queries" do
    test "returns empty list when there are no applications", %{tenant: tenant} do
      data = [tenant: tenant] |> list_applications() |> extract_result!()

      assert %{"applications" => %{"edges" => []}} = data
    end

    test "returns all the available applications", %{tenant: tenant} do
      app1 = application_fixture(name: "application 1", tenant: tenant)
      app2 = application_fixture(name: "application 2", tenant: tenant)

      data = [tenant: tenant] |> list_applications() |> extract_result!()

      assert %{"applications" => %{"edges" => applications}} = data

      names = applications |> Enum.map(& &1["node"]["name"]) |> Enum.sort()
      expected_names = [app1, app2] |> Enum.map(& &1.name) |> Enum.sort()

      assert names == expected_names
    end
  end

  defp list_applications(opts) do
    default_document =
      """
      query {
        applications {
          edges {
            node {
              name
              description
            }
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: data} = result
    assert data

    data
  end
end
