# This file is part of Edgehog.
#
# Copyright 2021 - 2025 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.UpdateSystemModelTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures

  alias Edgehog.Assets.SystemModelPictureMock
  alias Edgehog.Devices.SystemModel

  describe "updateSystemModel mutation" do
    setup %{tenant: tenant} do
      system_model =
        [tenant: tenant]
        |> system_model_fixture()
        |> Ash.load!(:part_number_strings)

      id = AshGraphql.Resource.encode_relay_id(system_model)

      %{system_model: system_model, id: id}
    end

    test "successfully updates with valid data", %{
      tenant: tenant,
      id: id
    } do
      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          name: "Updated Name",
          handle: "updatedhandle",
          part_numbers: "updated-1234"
        )

      system_model = extract_result!(result)

      assert %{
               "id" => _id,
               "name" => "Updated Name",
               "handle" => "updatedhandle",
               "partNumbers" => %{
                 "edges" => [
                   %{
                     "node" => %{"partNumber" => "updated-1234"}
                   }
                 ]
               }
             } = system_model
    end

    test "supports partial updates", %{tenant: tenant, system_model: system_model, id: id} do
      %{part_number_strings: old_part_numbers, handle: old_handle} = system_model

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          name: "Only Name Update"
        )

      system_model = extract_result!(result)

      assert %{
               "name" => "Only Name Update",
               "handle" => ^old_handle,
               "partNumbers" => %{
                 "edges" => part_numbers
               }
             } = system_model

      assert length(part_numbers) == length(old_part_numbers)

      Enum.each(old_part_numbers, fn pn ->
        assert %{"node" => %{"partNumber" => pn}} in part_numbers
      end)
    end

    test "manages part numbers correctly", %{tenant: tenant, id: id} do
      system_model_fixture(tenant: tenant, part_numbers: ["A", "B", "C"])

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          part_numbers: ["B", "D"]
        )

      system_model = extract_result!(result)

      assert %{"partNumbers" => %{"edges" => part_numbers}} = system_model
      assert length(part_numbers) == 2
      assert %{"node" => %{"partNumber" => "B"}} in part_numbers
      assert %{"node" => %{"partNumber" => "D"}} in part_numbers
    end

    test "allows updating localized descriptions", %{tenant: tenant} do
      initial_localized_descriptions = [
        %{language_tag: "en", value: "Description"},
        %{language_tag: "it", value: "Descrizione"}
      ]

      fixture =
        system_model_fixture(
          tenant: tenant,
          localized_descriptions: initial_localized_descriptions
        )

      id = AshGraphql.Resource.encode_relay_id(fixture)

      updated_localized_descriptions = [
        # nil value, so it will be removed
        %{"languageTag" => "en", "value" => nil},
        %{"languageTag" => "it", "value" => "Nuova descrizione"},
        %{"languageTag" => "bs", "value" => "Opis"}
      ]

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          localized_descriptions: updated_localized_descriptions
        )

      assert %{"localizedDescriptions" => localized_descriptions} = extract_result!(result)
      assert length(localized_descriptions) == 2
      assert %{"languageTag" => "it", "value" => "Nuova descrizione"} in localized_descriptions
      assert %{"languageTag" => "bs", "value" => "Opis"} in localized_descriptions
    end

    test "allows saving a picture url", %{tenant: tenant, id: id} do
      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          picture_url: "https://example.com/image.jpg"
        )

      assert %{"pictureUrl" => "https://example.com/image.jpg"} = extract_result!(result)
    end

    test "allows uploading a picture file", %{tenant: tenant, id: id} do
      picture_url = "https://example.com/image.jpg"

      expect(SystemModelPictureMock, :upload, fn _, _ -> {:ok, picture_url} end)

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert %{"pictureUrl" => ^picture_url} = extract_result!(result)
    end

    test "tries to delete the old picture when uploading a new picture file, but ignores failure",
         %{tenant: tenant} do
      old_picture_url = "https://example.com/old_image.jpg"

      system_model =
        system_model_fixture(tenant: tenant, picture_url: old_picture_url)

      id = AshGraphql.Resource.encode_relay_id(system_model)

      new_picture_url = "https://example.com/new_image.jpg"

      SystemModelPictureMock
      |> expect(:delete, fn _, ^old_picture_url -> {:error, :cannot_delete} end)
      |> expect(:upload, fn _, _ -> {:ok, new_picture_url} end)

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert %{"pictureUrl" => ^new_picture_url} = extract_result!(result)
    end

    test "doesn't delete the old picture if the URL is the same as the old one", %{tenant: tenant} do
      picture_url = "https://example.com/image.jpg"

      system_model =
        system_model_fixture(tenant: tenant, picture_url: picture_url)

      id = AshGraphql.Resource.encode_relay_id(system_model)

      SystemModelPictureMock
      |> expect(:upload, fn _, _ -> {:ok, picture_url} end)
      |> expect(:delete, 0, fn _, _ -> :ok end)

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert %{"pictureUrl" => ^picture_url} = extract_result!(result)
    end

    test "cleans up the image for a failed update", %{tenant: tenant, id: id} do
      duplicate = system_model_fixture(tenant: tenant)
      picture_url = "https://example.com/image.jpg"

      SystemModelPictureMock
      |> expect(:upload, fn _, _ -> {:ok, picture_url} end)
      |> expect(:delete, fn _, ^picture_url -> :ok end)

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          handle: duplicate.handle,
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert extract_error!(result)
    end

    test "returns error when passing both picture_file and picture_url", %{tenant: tenant, id: id} do
      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          picture_url: "https://example.com/image.jpg",
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert %{
               fields: [:picture_url],
               message: "is mutually exclusive with picture_file"
             } = extract_error!(result)
    end

    test "returns error when fails to update picture_file", %{tenant: tenant, id: id} do
      SystemModelPictureMock
      |> expect(:upload, fn _, _ -> {:error, :no_space_left} end)
      |> expect(:delete, 0, fn _, _ -> :ok end)

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          picture_file: %Plug.Upload{path: "/tmp/image.jpg", filename: "image.jpg"}
        )

      assert %{
               fields: [:picture_file],
               message: "failed to upload"
             } = extract_error!(result)
    end

    test "returns error for invalid handle", %{tenant: tenant, id: id} do
      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          handle: "123Invalid$"
        )

      assert %{fields: [:handle], message: "should only contain" <> _} =
               extract_error!(result)
    end

    test "returns error for empty part_numbers", %{
      tenant: tenant,
      id: id
    } do
      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          part_numbers: []
        )

      assert %{fields: [:part_numbers], message: "must have 1 or more items"} =
               extract_error!(result)
    end

    test "returns error for duplicate name", %{
      tenant: tenant,
      id: id
    } do
      fixture = system_model_fixture(tenant: tenant)

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          name: fixture.name
        )

      assert %{fields: [:name], message: "has already been taken"} =
               extract_error!(result)
    end

    test "returns error for duplicate handle", %{
      tenant: tenant,
      id: id
    } do
      fixture = system_model_fixture(tenant: tenant)

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          handle: fixture.handle
        )

      assert %{fields: [:handle], message: "has already been taken"} =
               extract_error!(result)
    end

    test "reassociates an existing SystemModelPartNumber", %{
      tenant: tenant,
      id: id
    } do
      # TODO: see issue #228, this documents the current behaviour

      fixture = system_model_fixture(tenant: tenant, part_numbers: ["foo", "bar"])

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          part_numbers: ["foo"]
        )

      _ = extract_result!(result)

      assert %SystemModel{part_number_strings: ["bar"]} =
               SystemModel
               |> Ash.get!(fixture.id, tenant: tenant)
               |> Ash.load!(:part_number_strings)
    end

    test "deletes unused SystemModelPartNumber", %{
      tenant: tenant,
      system_model: system_model,
      id: id
    } do
      %SystemModel{part_numbers: [%{id: old_system_model_part_number_id}]} = system_model

      result =
        update_system_model_mutation(
          tenant: tenant,
          id: id,
          part_numbers: ["other part number"]
        )

      _ = extract_result!(result)

      assert nil ==
               Ash.get!(Edgehog.Devices.SystemModelPartNumber, old_system_model_part_number_id,
                 tenant: tenant,
                 error?: false
               )
    end
  end

  defp update_system_model_mutation(opts) do
    default_document = """
    mutation UpdateSystemModel($id: ID!, $input: UpdateSystemModelInput!) {
      updateSystemModel(id: $id, input: $input) {
        result {
          id
          name
          localizedDescriptions {
            languageTag
            value
          }
          handle
          pictureUrl
          partNumbers {
            edges {
              node {
                partNumber
              }
            }
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    input =
      %{
        "handle" => opts[:handle],
        "name" => opts[:name],
        "localizedDescriptions" => opts[:localized_descriptions],
        "partNumbers" => opts[:part_numbers],
        "pictureUrl" => opts[:picture_url],
        "pictureFile" => opts[:picture_file] && "picture_file"
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Map.new()

    variables = %{"id" => id, "input" => input}

    document = Keyword.get(opts, :document, default_document)

    context =
      add_upload(%{tenant: tenant}, "picture_file", opts[:picture_file])

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"updateSystemModel" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateSystemModel" => %{
                 "result" => system_model
               }
             }
           } = result

    refute :errors in Map.keys(result)
    refute "errors" in Map.keys(result[:data])

    assert system_model

    system_model
  end
end
