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

defmodule EdgehogWeb.Schema.Query.ImageCredentialsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  describe "image credentials queries" do
    test "returns image credentials if present", %{tenant: tenant} do
      fixture = image_credentials_fixture(tenant: tenant)

      data = [tenant: tenant] |> list_image_credentials() |> extract_result!()

      assert %{"listImageCredentials" => %{"edges" => [image_credentials]}} = data
      assert image_credentials["node"]["label"] == fixture.label
      assert image_credentials["node"]["username"] == fixture.username
    end

    test "returns image credentials by id", %{tenant: tenant} do
      fixture = image_credentials_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      data = [tenant: tenant, id: id] |> image_credentials() |> extract_result!()

      assert %{"imageCredentials" => image_credentials} = data
      assert image_credentials["label"] == fixture.label
      assert image_credentials["username"] == fixture.username
    end
  end

  defp list_image_credentials(opts) do
    default_document =
      """
      query {
        listImageCredentials {
          edges {
            node {
             label
              username
            }
          }
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  defp image_credentials(opts) do
    default_document =
      """
      query ($id: ID!) {
        imageCredentials(id: $id) {
          label
          username
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    document = Keyword.get(opts, :document, default_document)

    variables = %{"id" => id}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: data} = result
    assert data

    data
  end
end
