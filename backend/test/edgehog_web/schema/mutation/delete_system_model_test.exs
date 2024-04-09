#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeleteSystemModelTest do
  use EdgehogWeb.GraphqlCase, async: true

  alias Edgehog.Devices
  alias Edgehog.Devices.SystemModel
  require Ash.Query

  import Edgehog.DevicesFixtures

  @moduletag :ported_to_ash

  describe "deleteSystemModel field" do
    setup %{tenant: tenant} do
      system_model =
        system_model_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(system_model)

      %{system_model: system_model, id: id}
    end

    test "deletes a system model", %{tenant: tenant, id: id, system_model: fixture} do
      system_model =
        delete_system_model_mutation(tenant: tenant, id: id)
        |> extract_result!()

      assert system_model["handle"] == fixture.handle

      refute SystemModel
             |> Ash.Query.filter(id == ^fixture.id)
             |> Ash.Query.set_tenant(tenant)
             |> Ash.exists?()
    end

    test "tries to delete the picture if there's one, but ignores failure", %{tenant: tenant} do
      picture_url = "https://example.com/image.jpg"

      fixture = system_model_fixture(tenant: tenant, picture_url: picture_url)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      Edgehog.Assets.SystemModelPictureMock
      |> expect(:delete, fn _, ^picture_url -> {:error, :cannot_delete} end)

      _ =
        delete_system_model_mutation(tenant: tenant, id: id)
        |> extract_result!()
    end

    test "fails with non-existing id", %{tenant: tenant} do
      id = non_existing_system_model_id(tenant)

      result = delete_system_model_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end
  end

  defp delete_system_model_mutation(opts) do
    default_document = """
    mutation DeleteSystemModel($id: ID!) {
      deleteSystemModel(id: $id) {
        result {
          id
          name
          handle
          pictureUrl
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    document = Keyword.get(opts, :document, default_document)
    variables = %{"id" => id}
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"deleteSystemModel" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "deleteSystemModel" => %{
                 "result" => system_model
               }
             }
           } = result

    assert system_model != nil

    system_model
  end

  defp non_existing_system_model_id(tenant) do
    fixture = system_model_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)
    :ok = Ash.destroy!(fixture)

    id
  end
end
