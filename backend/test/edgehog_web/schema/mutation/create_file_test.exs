#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.CreateFileTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.FilesFixtures

  describe "createFile mutation" do
    test "creates file with valid data", %{tenant: tenant} do
      repository = repository_fixture(tenant: tenant)

      repository_id =
        AshGraphql.Resource.encode_relay_id(repository)

      filename = "file-test.pdf"
      digest = "sha256:#{Base.encode16(:crypto.strong_rand_bytes(32))}"
      size = :rand.uniform(1_000_000)
      file_url = "https://example.com/file-test.pdf"

      file =
        [
          tenant: tenant,
          repository_id: repository_id,
          name: filename,
          digest: digest,
          size: size,
          url: file_url
        ]
        |> create_file_mutation()
        |> extract_result!()

      assert %{
               "id" => _,
               "name" => ^filename,
               "size" => ^size,
               "digest" => ^digest,
               "url" => ^file_url,
               "repository" => %{
                 "id" => ^repository_id
               }
             } = file
    end

    test "returns error for non-existing repository", %{tenant: tenant} do
      repository = repository_fixture(tenant: tenant)
      repository_id = AshGraphql.Resource.encode_relay_id(repository)
      _ = Ash.destroy!(repository)

      result =
        create_file_mutation(
          tenant: tenant,
          repository_id: repository_id
        )

      # TODO: wrong fields returned by AshGraphql
      assert %{fields: [:id], message: "could not be found" <> _} =
               extract_error!(result)
    end

    test "returns error for duplicate file name in the same repository", %{
      tenant: tenant
    } do
      repository = repository_fixture(tenant: tenant)

      file =
        file_fixture(tenant: tenant, repository_id: repository.id)

      result =
        create_file_mutation(
          tenant: tenant,
          name: file.name,
          size: file.size,
          digest: file.digest,
          url: file.url,
          repository_id: AshGraphql.Resource.encode_relay_id(repository)
        )

      assert %{fields: [:name], message: "has already been taken"} =
               extract_error!(result)
    end

    test "succeeds for duplicate file name on a different repository", %{tenant: tenant} do
      fixture = file_fixture(tenant: tenant)
      result = create_file_mutation(tenant: tenant, name: fixture.name)
      file = extract_result!(result)

      assert file["name"] == fixture.name
    end
  end

  # describe "PresignedUrl mutation" do
  #   test "returns presigned URLs containing the correct file path", %{tenant: tenant} do
  #     filename = "My File 1"

  #     repository = repository_fixture(tenant: tenant)

  #     repository_id = AshGraphql.Resource.encode_relay_id(repository)

  #     result =
  #       presigned_url_mutation(
  #         tenant: tenant,
  #         input: %{"filename" => filename, "repository_id" => repository_id}
  #       )

  #     assert %{data: %{"createFilePresignedUrl" => raw_json}} = result
  #     assert {:ok, decoded_map} = Jason.decode(raw_json)

  #     assert Map.has_key?(decoded_map, "get_url")
  #     assert Map.has_key?(decoded_map, "put_url")

  #     encoded_filename = URI.encode(filename)

  #     expected_path =
  #       "uploads/tenants/#{tenant.tenant_id}/repositories/#{repository.id}/files/#{encoded_filename}"

  #     assert decoded_map["get_url"] =~ expected_path
  #     assert decoded_map["put_url"] =~ expected_path
  #   end

  #   test "returns get presigned url only", %{tenant: tenant} do
  #     filename = "My File 1"

  #     repository = repository_fixture(tenant: tenant)

  #     repository_id = AshGraphql.Resource.encode_relay_id(repository)

  #     result =
  #       presigned_url_mutation(
  #         tenant: tenant,
  #         document: """
  #         mutation ReadFilePresignedUrl($input: ReadFilePresignedUrlInput!) {
  #           readFilePresignedUrl(input: $input)
  #         }
  #         """,
  #         input: %{"filename" => filename, "repository_id" => repository_id}
  #       )

  #     assert %{data: %{"readFilePresignedUrl" => raw_json}} = result
  #     assert {:ok, decoded_map} = Jason.decode(raw_json)

  #     assert Map.has_key?(decoded_map, "get_url")

  #     encoded_filename = URI.encode(filename)

  #     expected_path =
  #       "uploads/tenants/#{tenant.tenant_id}/repositories/#{repository.id}/files/#{encoded_filename}"

  #     assert decoded_map["get_url"] =~ expected_path
  #   end

  #   defp presigned_url_mutation(opts) do
  #     default_document = """
  #     mutation CreateFilePresignedUrl($input: CreateFilePresignedUrlInput!) {
  #       createFilePresignedUrl(input: $input)
  #     }
  #     """

  #     {tenant, opts} = Keyword.pop!(opts, :tenant)
  #     {input_overrides, opts} = Keyword.pop(opts, :input, %{})

  #     # Use repository_id from input overrides or default
  #     default_input = %{
  #       "filename" => "My File",
  #       "repository_id" => input_overrides["repository_id"] || nil
  #     }

  #     input = Map.merge(default_input, input_overrides)

  #     context = %{tenant: tenant}
  #     variables = %{"input" => input}
  #     document = Keyword.get(opts, :document, default_document)

  #     Absinthe.run!(document, EdgehogWeb.Schema,
  #       variables: variables,
  #       context: context
  #     )
  #   end
  # end

  defp create_file_mutation(opts) do
    default_document = """
    mutation CreateFile($input: CreateFileInput!) {
      createFile(input: $input) {
        result {
          id
          name
          size
          digest
          mode
          userId
          groupId
          url
          repository {
            id
            name
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {repository_id, opts} =
      Keyword.pop_lazy(opts, :repository_id, fn ->
        [tenant: tenant]
        |> repository_fixture()
        |> AshGraphql.Resource.encode_relay_id()
      end)

    {name, opts} = Keyword.pop_lazy(opts, :name, &unique_file_name/0)

    {digest, opts} =
      Keyword.pop_lazy(opts, :digest, fn ->
        "sha256:#{Base.encode16(:crypto.strong_rand_bytes(32))}"
      end)

    {size, opts} = Keyword.pop_lazy(opts, :size, fn -> :rand.uniform(1_000_000) end)
    {url, opts} = Keyword.pop_lazy(opts, :url, fn -> "https://example.com/#{name}" end)

    variables = %{
      "input" => %{
        "name" => name,
        "size" => size,
        "digest" => digest,
        "url" => url,
        "repositoryId" => repository_id
      }
    }

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant}
    )
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createFile"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "createFile" => %{
                 "result" => file
               }
             }
           } = result

    refute Map.get(result, :errors)
    file
  end
end
