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

  alias Edgehog.Files.StorageMock

  describe "createFile mutation" do
    setup %{tenant: tenant} do
      repository = repository_fixture(tenant: tenant)
      repository_id = AshGraphql.Resource.encode_relay_id(repository)

      # Create a real temp file so File.stat! and digest calculation work
      tmp_path =
        Path.join(System.tmp_dir!(), "test_upload_#{:erlang.unique_integer([:positive])}.bin")

      File.write!(tmp_path, "test file content")
      on_exit(fn -> File.rm(tmp_path) end)

      upload = %Plug.Upload{
        path: tmp_path,
        filename: "test.bin",
        content_type: "application/octet-stream"
      }

      %{repository: repository, repository_id: repository_id, upload: upload, tmp_path: tmp_path}
    end

    test "creates a file with valid data", %{
      repository: repository,
      tenant: tenant,
      repository_id: repository_id,
      upload: upload
    } do
      filename = "some-name.bin"
      base_file_url = "https://example.com/some-name.bin"
      gz_file_url = "https://example.com/encoding/gz/some-name.bin.gz"
      lz4_file_url = "https://example.com/encoding/lz4/some-name.bin.lz4"

      expect(StorageMock, :store, 3, fn tenant_id,
                                        filename_arg,
                                        repository_id,
                                        encoding,
                                        _upload ->
        assert tenant_id == tenant.tenant_id
        assert repository_id == repository.id

        case {encoding, filename_arg} do
          {nil, ^filename} ->
            {:ok, base_file_url}

          {:gz, ^filename} ->
            {:ok, gz_file_url}

          {:lz4, ^filename} ->
            {:ok, lz4_file_url}

          other ->
            flunk("Unexpected call to store/5: #{inspect(other)}")
        end
      end)

      result =
        [tenant: tenant, repository_id: repository_id, name: filename, file: upload]
        |> create_file_mutation()
        |> extract_result!()

      assert result["name"] == filename
      assert result["baseFile"]["url"] == base_file_url
      assert result["size"] > 0
      assert result["baseFile"]["digest"] =~ ~r/^sha256:[a-f0-9]+$/
    end

    test "returns error when storage fails", %{
      tenant: tenant,
      repository_id: repository_id,
      upload: upload
    } do
      Mox.expect(StorageMock, :store, 3, fn _tenant_id,
                                            _name,
                                            _repository_id,
                                            _encoding,
                                            _upload ->
        {:error, :storage_unavailable}
      end)

      result =
        create_file_mutation(
          tenant: tenant,
          repository_id: repository_id,
          name: "fail.bin",
          file: upload
        )

      assert %{message: message} = extract_error!(result)
      assert message =~ "upload" or message =~ "failed"
    end

    test "returns error when name is missing", %{
      tenant: tenant,
      repository_id: repository_id,
      upload: upload
    } do
      Mox.expect(StorageMock, :store, 0, fn _tenant_id,
                                            _name,
                                            _repository_id,
                                            _encoding,
                                            _upload ->
        {:ok, "https://bucket.example.com/file.bin"}
      end)

      document = """
      mutation CreateFile($input: CreateFileInput!) {
        createFile(input: $input) {
          result {
            id
          }
        }
      }
      """

      input = %{
        "repositoryId" => repository_id,
        "file" => "file"
      }

      context = add_upload(%{tenant: tenant}, "file", upload)

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"input" => input},
          context: context
        )

      assert %{errors: [_ | _]} = result
    end

    test "returns error when repository_id is missing", %{
      tenant: tenant,
      upload: upload
    } do
      document = """
      mutation CreateFile($input: CreateFileInput!) {
        createFile(input: $input) {
          result {
            id
          }
        }
      }
      """

      input = %{
        "name" => "test.bin",
        "file" => "file"
      }

      context = add_upload(%{tenant: tenant}, "file", upload)

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"input" => input},
          context: context
        )

      assert %{errors: [_ | _]} = result
    end

    test "returns error when file argument is missing", %{
      tenant: tenant,
      repository_id: repository_id
    } do
      document = """
      mutation CreateFile($input: CreateFileInput!) {
        createFile(input: $input) {
          result {
            id
          }
        }
      }
      """

      input = %{
        "name" => "test.bin",
        "repositoryId" => repository_id
      }

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"input" => input},
          context: %{tenant: tenant}
        )

      assert %{errors: [_ | _]} = result
    end

    test "file is associated with the correct repository", %{
      tenant: tenant,
      repository: repository,
      repository_id: repository_id,
      upload: upload
    } do
      Mox.expect(StorageMock, :store, 3, fn _tenant_id,
                                            _name,
                                            _repository_id,
                                            _encoding,
                                            _upload ->
        {:ok, "https://bucket.example.com/assoc.bin"}
      end)

      result =
        [tenant: tenant, repository_id: repository_id, name: "assoc.bin", file: upload]
        |> create_file_mutation()
        |> extract_result!()

      expected_repo_id = AshGraphql.Resource.encode_relay_id(repository)
      assert result["repository"]["id"] == expected_repo_id
    end

    test "computes correct digest for file content", %{
      tenant: tenant,
      repository_id: repository_id,
      tmp_path: tmp_path
    } do
      Mox.expect(StorageMock, :store, 3, fn _tenant_id,
                                            _name,
                                            _repository_id,
                                            _encoding,
                                            _upload ->
        {:ok, "https://bucket.example.com/digest.bin"}
      end)

      # Compute expected digest
      expected_hash =
        tmp_path
        |> File.stream!(2048)
        |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
        |> :crypto.hash_final()
        |> Base.encode16(case: :lower)

      expected_digest = "sha256:#{expected_hash}"

      upload = %Plug.Upload{path: tmp_path, filename: "digest.bin"}

      result =
        [tenant: tenant, repository_id: repository_id, name: "digest.bin", file: upload]
        |> create_file_mutation()
        |> extract_result!()

      assert result["baseFile"]["digest"] == expected_digest
    end
  end

  defp create_file_mutation(opts) do
    default_document = """
    mutation CreateFile($input: CreateFileInput!) {
      createFile(input: $input) {
        result {
          id
          name
          size
          baseFile {
            url
            digest
          }
          gzFile {
            url
            digest
          }
          lz4File {
            url
            digest
          }
          repository {
            id
          }
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {repository_id, opts} = Keyword.pop!(opts, :repository_id)
    {name, opts} = Keyword.pop!(opts, :name)
    {size, opts} = Keyword.pop_lazy(opts, :size, fn -> :rand.uniform(1_000_000) end)

    {file, opts} = Keyword.pop!(opts, :file)

    input =
      %{
        "repositoryId" => repository_id,
        "name" => name,
        "file" => file && "file",
        "size" => size
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    variables = %{"input" => input}
    document = Keyword.get(opts, :document, default_document)

    context =
      add_upload(%{tenant: tenant}, "file", file)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: context
    )
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["createFile"]) or
             is_nil(get_in(result, [:data, "createFile"]))

    assert %{errors: [error | _]} = result

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
    assert file

    file
  end
end
