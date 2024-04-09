#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateSystemModelTest do
  use EdgehogWeb.GraphqlCase, async: true

  alias Edgehog.Devices
  alias Edgehog.Devices.SystemModel

  import Edgehog.DevicesFixtures

  @moduletag :ported_to_ash

  describe "createSystemModel mutation" do
    test "creates system model with valid data", %{tenant: tenant} do
      hardware_type_id =
        hardware_type_fixture(tenant: tenant)
        |> AshGraphql.Resource.encode_relay_id()

      result =
        create_system_model_mutation(
          hardware_type_id: hardware_type_id,
          tenant: tenant,
          name: "Foobar",
          handle: "foobar",
          part_numbers: ["123", "456"]
        )

      system_model = extract_result!(result)

      assert %{
               "id" => _,
               "name" => "Foobar",
               "handle" => "foobar",
               "pictureUrl" => nil,
               "partNumbers" => part_numbers,
               "hardwareType" => %{
                 "id" => ^hardware_type_id
               }
             } = system_model

      assert length(part_numbers) == 2
      assert %{"partNumber" => "123"} in part_numbers
      assert %{"partNumber" => "456"} in part_numbers
    end

    test "allows saving a picture url", %{tenant: tenant} do
      result =
        create_system_model_mutation(
          tenant: tenant,
          picture_url: "https://example.com/image.jpg"
        )

      assert %{"pictureUrl" => "https://example.com/image.jpg"} = extract_result!(result)
    end

    test "allows uploading a picture file", %{tenant: tenant} do
      picture_url = "https://example.com/image.jpg"

      Edgehog.Assets.SystemModelPictureMock
      |> expect(:upload, fn _, _ ->
        {:ok, picture_url}
      end)

      result =
        create_system_model_mutation(
          tenant: tenant,
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert %{"pictureUrl" => ^picture_url} = extract_result!(result)
    end

    test "returns error when passing both picture_file and picture_url", %{tenant: tenant} do
      result =
        create_system_model_mutation(
          tenant: tenant,
          picture_url: "https://example.com/image.jpg",
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert %{
               fields: [:picture_url],
               message: "is mutually exclusive with picture_file"
             } = extract_error!(result)
    end

    test "cleans up the image for a failed create", %{tenant: tenant} do
      duplicate = system_model_fixture(tenant: tenant)

      picture_url = "https://example.com/image.jpg"

      Edgehog.Assets.SystemModelPictureMock
      |> expect(:upload, fn _, _ -> {:ok, picture_url} end)
      |> expect(:delete, fn _, ^picture_url -> :ok end)

      result =
        create_system_model_mutation(
          tenant: tenant,
          handle: duplicate.handle,
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert extract_error!(result)
    end

    test "returns error for non-existing hardware type", %{tenant: tenant} do
      hardware_type = hardware_type_fixture(tenant: tenant)
      hardware_type_id = AshGraphql.Resource.encode_relay_id(hardware_type)
      _ = Ash.destroy!(hardware_type)

      result =
        create_system_model_mutation(
          tenant: tenant,
          hardware_type_id: hardware_type_id
        )

      # TODO: wrong fields returned by AshGraphql
      assert %{fields: [:id], message: "could not be found" <> _} =
               extract_error!(result)
    end

    test "returns error for invalid handle", %{tenant: tenant} do
      result =
        create_system_model_mutation(
          tenant: tenant,
          handle: "123Invalid$"
        )

      assert %{fields: [:handle], message: "should only contain" <> _} =
               extract_error!(result)
    end

    test "returns error for empty part_numbers", %{tenant: tenant} do
      result =
        create_system_model_mutation(
          tenant: tenant,
          part_numbers: []
        )

      assert %{fields: [:part_numbers], message: "must have 1 or more items"} =
               extract_error!(result)
    end

    test "returns error for duplicate name", %{tenant: tenant} do
      fixture = system_model_fixture(tenant: tenant)

      result =
        create_system_model_mutation(
          tenant: tenant,
          name: fixture.name
        )

      assert %{fields: [:name], message: "has already been taken"} =
               extract_error!(result)
    end

    test "returns error for duplicate handle", %{tenant: tenant} do
      fixture = system_model_fixture(tenant: tenant)

      result =
        create_system_model_mutation(
          tenant: tenant,
          handle: fixture.handle
        )

      assert %{fields: [:handle], message: "has already been taken"} =
               extract_error!(result)
    end

    test "reassociates an existing SystemModelPartNumber", %{tenant: tenant} do
      # TODO: see issue #228, this documents the current behaviour

      fixture = system_model_fixture(tenant: tenant, part_numbers: ["foo", "bar"])

      result =
        create_system_model_mutation(
          tenant: tenant,
          part_numbers: ["foo"]
        )

      _ = extract_result!(result)

      assert %SystemModel{part_number_strings: ["bar"]} =
               SystemModel
               |> Ash.get!(fixture.id, tenant: tenant)
               |> Ash.load!(:part_number_strings)
    end
  end

  defp create_system_model_mutation(opts) do
    default_document = """
    mutation CreateSystemModel($input: CreateSystemModelInput!) {
      createSystemModel(input: $input) {
        result {
          id
          name
          handle
          pictureUrl
          partNumbers {
            partNumber
          }
          hardwareType {
            id
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {hardware_type_id, opts} =
      Keyword.pop_lazy(opts, :hardware_type_id, fn ->
        hardware_type_fixture(tenant: tenant)
        |> AshGraphql.Resource.encode_relay_id()
      end)

    input = %{
      "hardwareTypeId" => hardware_type_id,
      "handle" => opts[:handle] || unique_system_model_handle(),
      "name" => opts[:name] || unique_system_model_name(),
      "partNumbers" => opts[:part_numbers] || [unique_system_model_part_number()],
      "pictureUrl" => opts[:picture_url],
      "pictureFile" => opts[:picture_file] && "picture_file"
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    context =
      %{tenant: tenant}
      |> add_upload("picture_file", opts[:picture_file])

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: context
    )
  end

  defp extract_error!(result) do
    assert %{
             data: %{"createSystemModel" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert %{
             data: %{
               "createSystemModel" => %{
                 "result" => system_model
               }
             }
           } = result

    assert system_model != nil

    system_model
  end
end
