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

      tmp_path = build_temp_file!("test.bin", "test file content")

      upload = plug_upload(tmp_path, "test.bin")

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
      assert result["isArchive"] == false
    end

    test "marks file as archive when USTAR", %{tenant: tenant, repository_id: repo_id} do
      binary = :binary.copy(<<0>>, 257) <> "ustar"
      path = build_temp_file!("ustar.tar", binary)
      upload = plug_upload(path, "ustar.tar")

      Mox.expect(StorageMock, :store, 3, fn _, _, _, _, _ ->
        {:ok, "https://example.com/file.tar"}
      end)

      result =
        [tenant: tenant, repository_id: repo_id, name: "ustar.tar", file: upload]
        |> create_file_mutation()
        |> extract_result!()

      assert result["isArchive"] == true
    end

    test "fails for zip archive", %{tenant: tenant, repository_id: repo_id} do
      binary = <<0x50, 0x4B, 0x03, 0x04>>
      path = build_temp_file!("file.zip", binary)
      upload = plug_upload(path, "file.zip")

      result =
        create_file_mutation(
          tenant: tenant,
          repository_id: repo_id,
          name: "file.zip",
          file: upload
        )

      assert [%{message: message}] = extract_error!(result)
      assert message =~ "Only USTAR tar archives are supported"
    end

    test "fails for rar archive", %{tenant: tenant, repository_id: repo_id} do
      binary = <<0x52, 0x61, 0x72, 0x21>>
      path = build_temp_file!("file.rar", binary)
      upload = plug_upload(path, "file.rar")

      result =
        create_file_mutation(
          tenant: tenant,
          repository_id: repo_id,
          name: "file.rar",
          file: upload
        )

      assert [%{message: message}] = extract_error!(result)
      assert message =~ "Only USTAR tar archives are supported"
    end

    test "fails for 7z archive", %{tenant: tenant, repository_id: repo_id} do
      binary = <<0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C>>
      path = build_temp_file!("file.7z", binary)
      upload = plug_upload(path, "file.7z")

      result =
        create_file_mutation(
          tenant: tenant,
          repository_id: repo_id,
          name: "file.7z",
          file: upload
        )

      assert [%{message: message}] = extract_error!(result)
      assert message =~ "Only USTAR tar archives are supported"
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

      errors = extract_error!(result)

      messages =
        Enum.map(errors, fn %{message: msg} -> msg end)

      expected_messages = [
        "Upload failed for base file",
        "Upload failed for gz file",
        "Upload failed for lz4 file"
      ]

      assert Enum.sort(messages) == Enum.sort(expected_messages)
    end

    test "returns error when storage fails and cleans up successful uploads", %{
      repository: repository,
      tenant: tenant,
      repository_id: repository_id,
      upload: upload
    } do
      filename = "some-name.bin"
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
            {:error, :storage_unavailable}

          {:gz, ^filename} ->
            {:error, :storage_unavailable}

          {:lz4, ^filename} ->
            {:ok, lz4_file_url}

          other ->
            flunk("Unexpected call to store/5: #{inspect(other)}")
        end
      end)

      Mox.expect(StorageMock, :delete, 1, fn _file, :lz4 ->
        :ok
      end)

      result =
        create_file_mutation(
          tenant: tenant,
          repository_id: repository_id,
          name: filename,
          file: upload
        )

      errors = extract_error!(result)

      messages =
        Enum.map(errors, fn %{message: msg} -> msg end)

      expected_messages = [
        "Upload failed for base file",
        "Upload failed for gz file"
      ]

      assert Enum.sort(messages) == Enum.sort(expected_messages)
    end

    test "returns error when storage fails and cleans up a successful base upload", %{
      repository: repository,
      tenant: tenant,
      repository_id: repository_id,
      upload: upload
    } do
      filename = "some-name.bin"
      base_file_url = "https://example.com/some-name.bin"

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
            {:error, :storage_unavailable}

          {:lz4, ^filename} ->
            {:error, :storage_unavailable}

          other ->
            flunk("Unexpected call to store/5: #{inspect(other)}")
        end
      end)

      Mox.expect(StorageMock, :delete, 1, fn file, nil ->
        assert file.name == filename
        assert file.base_file.url == base_file_url
        :ok
      end)

      result =
        create_file_mutation(
          tenant: tenant,
          repository_id: repository_id,
          name: filename,
          file: upload
        )

      errors = extract_error!(result)

      messages =
        Enum.map(errors, fn %{message: msg} -> msg end)

      expected_messages = [
        "Upload failed for gz file",
        "Upload failed for lz4 file"
      ]

      assert Enum.sort(messages) == Enum.sort(expected_messages)
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
          isArchive
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

    assert %{errors: errors} = result

    errors
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

  defp build_temp_file!(filename, content) do
    path =
      Path.join(
        System.tmp_dir!(),
        "test_upload_#{System.unique_integer([:positive])}_#{filename}"
      )

    File.write!(path, content)

    ExUnit.Callbacks.on_exit(fn ->
      File.rm(path)
    end)

    path
  end

  defp plug_upload(path, filename) do
    %Plug.Upload{
      path: path,
      filename: filename,
      content_type: "application/octet-stream"
    }
  end
end
