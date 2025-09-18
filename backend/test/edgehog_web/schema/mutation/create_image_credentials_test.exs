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

defmodule EdgehogWeb.Schema.Mutation.CreateImageCredentialsTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  describe "createImageCredentials mutation" do
    test "create image credentials with valid data", %{tenant: tenant} do
      label = "valid_label"
      username = "valid_username"
      password = "valid_password"

      image_credentials =
        [tenant: tenant, label: label, username: username, password: password]
        |> create_image_credentials_mutation()
        |> extract_result!()

      assert image_credentials["label"] == label
      assert image_credentials["username"] == username
    end

    test "fails with invalid label", %{tenant: tenant} do
      fixture = image_credentials_fixture(tenant: tenant)

      image_credentials_error =
        [tenant: tenant, label: fixture.label]
        |> create_image_credentials_mutation()
        |> extract_error!()

      assert %{fields: [:label]} = image_credentials_error
    end
  end

  def create_image_credentials_mutation(opts) do
    default_document = """
    mutation CreateImageCredentials($input: CreateImageCredentialsInput!) {
      createImageCredentials(input: $input) {
        result {
          label
          username
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    input = %{
      "label" => opts[:label] || unique_image_credentials_label(),
      "username" => opts[:username] || unique_image_credentials_username(),
      "password" => opts[:password] || unique_image_credentials_password()
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    assert %{
             data: %{
               "createImageCredentials" => %{
                 "result" => image_credentials
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert image_credentials != nil

    image_credentials
  end

  def extract_error!(result) do
    assert %{
             data: %{
               "createImageCredentials" => nil
             },
             errors: [error]
           } = result

    error
  end
end
