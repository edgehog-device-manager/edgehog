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

defmodule EdgehogWeb.Schema.Mutation.CreateBaseImageTest do
  use EdgehogWeb.GraphqlCase, async: true
  use Edgehog.BaseImagesStorageMockCase

  import Edgehog.BaseImagesFixtures

  @moduletag :ported_to_ash

  describe "createBaseImage mutation" do
    test "creates base image with valid data", %{tenant: tenant} do
      base_image_collection_id =
        base_image_collection_fixture(tenant: tenant)
        |> AshGraphql.Resource.encode_relay_id()

      file_url = "https://example.com/ota.bin"

      Edgehog.BaseImages.StorageMock
      |> expect(:store, fn _, _ -> {:ok, file_url} end)

      result =
        create_base_image_mutation(
          tenant: tenant,
          base_image_collection_id: base_image_collection_id,
          version: "2.0.0",
          starting_version_requirement: "~> 1.0",
          file: %Plug.Upload{path: "/tmp/ota.bin", filename: "ota.bin"}
        )

      base_image = extract_result!(result)

      assert %{
               "id" => _,
               "version" => "2.0.0",
               "startingVersionRequirement" => "~> 1.0",
               "url" => ^file_url,
               "baseImageCollection" => %{
                 "id" => ^base_image_collection_id
               }
             } = base_image
    end

    test "returns error for non-existing base image collection", %{tenant: tenant} do
      base_image_collection = base_image_collection_fixture(tenant: tenant)
      base_image_collection_id = AshGraphql.Resource.encode_relay_id(base_image_collection)
      _ = Ash.destroy!(base_image_collection)

      result =
        create_base_image_mutation(
          tenant: tenant,
          base_image_collection_id: base_image_collection_id
        )

      # TODO: wrong fields returned by AshGraphql
      assert %{fields: [:id], message: "could not be found" <> _} =
               extract_error!(result)
    end

    test "returns error for missing version", %{tenant: tenant} do
      result = create_base_image_mutation(tenant: tenant, version: nil)

      assert %{message: message} = extract_error!(result)

      assert String.contains?(
               message,
               "In field \"version\": Expected type \"String!\", found null."
             )
    end

    test "returns error for empty version", %{tenant: tenant} do
      result = create_base_image_mutation(tenant: tenant, version: "")

      assert %{fields: [:version], message: "is required"} =
               extract_error!(result)
    end

    test "returns error for invalid version", %{tenant: tenant} do
      result = create_base_image_mutation(tenant: tenant, version: "invalid")

      assert %{fields: [:version], message: "is not a valid version"} =
               extract_error!(result)
    end

    test "returns error for invalid starting version requirement", %{tenant: tenant} do
      result =
        create_base_image_mutation(
          tenant: tenant,
          starting_version_requirement: "invalid"
        )

      assert %{
               fields: [:starting_version_requirement],
               message: "is not a valid version requirement"
             } =
               extract_error!(result)
    end

    test "returns error for duplicate version in the same base image collection", %{
      tenant: tenant
    } do
      base_image_collection = base_image_collection_fixture(tenant: tenant)

      base_image =
        base_image_fixture(tenant: tenant, base_image_collection_id: base_image_collection.id)

      result =
        create_base_image_mutation(
          tenant: tenant,
          version: base_image.version,
          base_image_collection_id: AshGraphql.Resource.encode_relay_id(base_image_collection)
        )

      assert %{fields: [:version], message: "has already been taken"} =
               extract_error!(result)
    end

    test "succeeds for duplicate version on a different base image collection", %{tenant: tenant} do
      fixture = base_image_fixture(tenant: tenant)
      result = create_base_image_mutation(tenant: tenant, version: fixture.version)
      base_image = extract_result!(result)

      assert base_image["version"] == fixture.version
    end

    test "doesn't upload the base image to the storage with invalid data", %{tenant: tenant} do
      Edgehog.BaseImages.StorageMock
      |> expect(:store, 0, fn _, _ -> {:error, :unreachable} end)

      result = create_base_image_mutation(tenant: tenant, version: "invalid")

      assert %{message: "is not a valid version"} = extract_error!(result)
    end

    test "returns error if the upload to the storage fails", %{tenant: tenant} do
      Edgehog.BaseImages.StorageMock
      |> expect(:store, fn _, _ -> {:error, :bucket_is_full} end)

      result = create_base_image_mutation(tenant: tenant)

      assert %{
               fields: [:file],
               message: "failed to upload"
             } = extract_error!(result)
    end

    test "attempts to delete the uploaded file when the mutation fails", %{tenant: tenant} do
      Edgehog.BaseImages.StorageMock
      |> expect(:delete, fn _ -> :ok end)

      # Simulate a mutation that fail because of unique constraints on :version
      # so that data validation succeeds but the database transaction fails.

      base_image_collection = base_image_collection_fixture(tenant: tenant)

      base_image =
        base_image_fixture(tenant: tenant, base_image_collection_id: base_image_collection.id)

      result =
        create_base_image_mutation(
          tenant: tenant,
          version: base_image.version,
          base_image_collection_id: AshGraphql.Resource.encode_relay_id(base_image_collection)
        )

      assert %{message: "has already been taken"} = extract_error!(result)
    end
  end

  defp create_base_image_mutation(opts) do
    default_document = """
    mutation CreateBaseImage($input: CreateBaseImageInput!) {
      createBaseImage(input: $input) {
        result {
          id
          version
          url
          startingVersionRequirement
          baseImageCollection {
            id
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {base_image_collection_id, opts} =
      Keyword.pop_lazy(opts, :base_image_collection_id, fn ->
        base_image_collection_fixture(tenant: tenant)
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {version, opts} = Keyword.pop_lazy(opts, :version, &unique_base_image_version/0)

    {file, opts} =
      Keyword.pop_lazy(opts, :file, fn ->
        %Plug.Upload{path: "/tmp/ota.bin", filename: "ota.bin"}
      end)

    input = %{
      "baseImageCollectionId" => base_image_collection_id,
      "version" => version,
      "startingVersionRequirement" => opts[:starting_version_requirement],
      "file" => file && "file"
    }

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    context =
      %{tenant: tenant}
      |> add_upload("file", file)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: context
    )
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createBaseImage"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createBaseImage" => %{
                 "result" => base_image
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert base_image != nil

    base_image
  end
end
