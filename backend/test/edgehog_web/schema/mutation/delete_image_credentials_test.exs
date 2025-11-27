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

defmodule EdgehogWeb.Schema.Mutation.DeleteImageCredentialsTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  describe "deleteImageCredentials mutation" do
    setup %{tenant: tenant} do
      image_credentials = image_credentials_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(image_credentials)

      %{image_credentials: image_credentials, id: id}
    end

    test "delete image credentials with valid data", %{
      tenant: tenant,
      image_credentials: image_credentials,
      id: id
    } do
      delete_image_credentials =
        [tenant: tenant, id: id]
        |> delete_image_credentials_mutation()
        |> extract_result!()

      assert delete_image_credentials["label"] == image_credentials.label
      assert delete_image_credentials["username"] == image_credentials.username
    end

    test "delete image credentials fails with invalid data", %{tenant: tenant} do
      id = "An invalid id!"

      delete_image_credentials =
        [tenant: tenant, id: id]
        |> delete_image_credentials_mutation()
        |> extract_error!()

      assert %{code: "invalid_primary_key"} = delete_image_credentials
    end
  end

  def delete_image_credentials_mutation(opts) do
    default_document = """
    mutation DeleteImageCredentials($id: ID!) {
      deleteImageCredentials(id: $id) {
        result {
          label
          username
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    variables = %{"id" => id}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    assert %{
             data: %{
               "deleteImageCredentials" => %{
                 "result" => image_credentials
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert image_credentials

    image_credentials
  end

  def extract_error!(result) do
    assert %{
             data: %{
               "deleteImageCredentials" => nil
             },
             errors: [error]
           } = result

    error
  end
end
