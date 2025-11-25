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

defmodule EdgehogWeb.Schema.Mutation.CreateApplicationTest do
  @moduledoc false

  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  describe "createApplication mutation" do
    test "create application with valid data", %{tenant: tenant} do
      name = "application_name"
      description = "application description"

      application =
        [tenant: tenant, name: name, description: description]
        |> create_application_mutation()
        |> extract_result!()

      assert application["name"] == name
      assert application["description"] == description
    end

    test "create application with valid data and nested initial release", %{tenant: tenant} do
      name = "application_name"
      description = "application description"
      hostname = unique_container_hostname()
      reference = unique_image_reference()

      initial_release = %{
        "version" => "0.0.1",
        "containers" => [
          %{
            "hostname" => hostname,
            "image" => %{
              "reference" => reference
            }
          }
        ]
      }

      input = %{
        "name" => name,
        "description" => description,
        "InitialRelease" => initial_release
      }

      document = """
      mutation CreateApplication($input: CreateApplicationInput!) {
        createApplication(input: $input) {
          result {
            name
            description
            releases {
              edges {
                node {
                  containers {
                    edges {
                      node {
                        hostname
                        image {
                          reference
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      """

      application =
        [tenant: tenant, input: input, document: document]
        |> create_application_mutation()
        |> extract_result!()

      assert application["name"] == name
      assert application["description"] == description

      assert %{
               "releases" => %{
                 "edges" => [
                   %{
                     "node" => %{
                       "containers" => %{
                         "edges" => [
                           %{"node" => container_result}
                         ]
                       }
                     }
                   }
                 ]
               }
             } = application

      assert container_result["hostname"] == hostname

      assert %{"image" => image_result} = container_result

      assert image_result["reference"] == reference
    end
  end

  def create_application_mutation(opts) do
    default_document = """
    mutation CreateApplication($input: CreateApplicationInput!) {
      createApplication(input: $input) {
        result {
          name
          description
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    default_input = %{
      "name" => Keyword.get(opts, :name, unique_application_name()),
      "description" => Keyword.get(opts, :description, unique_application_description())
    }

    input = Keyword.get(opts, :input, default_input)

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    assert %{
             data: %{
               "createApplication" => %{
                 "result" => application
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert application

    application
  end
end
