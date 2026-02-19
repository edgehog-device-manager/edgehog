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

defmodule EdgehogWeb.Schema.Mutation.DeleteFileTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.FilesFixtures

  alias Edgehog.Files.StorageMock

  describe "deleteFile mutation" do
    setup %{tenant: tenant} do
      repository = repository_fixture(tenant: tenant)

      file =
        file_fixture(
          tenant: tenant,
          repository_id: repository.id,
          name: "deletable.bin",
          url: "https://bucket.example.com/deletable.bin"
        )

      id = AshGraphql.Resource.encode_relay_id(file)

      %{file_record: file, id: id}
    end

    test "deletes an existing file", %{tenant: tenant, id: id} do
      Mox.expect(StorageMock, :delete, fn _file ->
        :ok
      end)

      result =
        [tenant: tenant, id: id]
        |> delete_file_mutation()
        |> extract_result!()

      assert result["id"] == id
    end

    test "calls storage delete after successful deletion", %{tenant: tenant, id: id} do
      test_pid = self()

      Mox.expect(StorageMock, :delete, fn file ->
        send(test_pid, {:storage_delete_called, file.name})
        :ok
      end)

      [tenant: tenant, id: id]
      |> delete_file_mutation()
      |> extract_result!()

      assert_receive {:storage_delete_called, "deletable.bin"}
    end

    test "succeeds even if storage delete fails", %{tenant: tenant, id: id} do
      Mox.expect(StorageMock, :delete, fn _file ->
        {:error, :storage_unavailable}
      end)

      # The mutation should still succeed; storage errors are logged but don't fail the delete
      result =
        [tenant: tenant, id: id]
        |> delete_file_mutation()
        |> extract_result!()

      assert result["id"] == id
    end

    test "returns error for non-existing file", %{tenant: tenant, file_record: file, id: id} do
      # Delete via fixture action (no storage call)
      _ = Ash.destroy!(file, action: :destroy_fixture, tenant: tenant)

      result = delete_file_mutation(tenant: tenant, id: id)

      assert %{message: "could not be found" <> _} = extract_error!(result)
    end

    test "verifies file is actually deleted from database", %{tenant: tenant, id: id} do
      Mox.expect(StorageMock, :delete, fn _file -> :ok end)

      delete_file_mutation(tenant: tenant, id: id)

      # File query is commented out in domain, so verify via Ash directly
      assert Edgehog.Files.File
             |> Ash.get(file_id(id), tenant: tenant)
             |> elem(0) == :error
    end
  end

  # Decode the relay ID to get the raw UUID for direct lookup
  defp file_id(relay_id) do
    {:ok, %{id: id}} = AshGraphql.Resource.decode_relay_id(relay_id)
    id
  end

  defp delete_file_mutation(opts) do
    document = """
    mutation DeleteFile($id: ID!) {
      deleteFile(id: $id) {
        result {
          id
          name
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: %{"id" => id},
      context: %{tenant: tenant}
    )
  end

  defp extract_error!(result) do
    assert %{
             data: %{"deleteFile" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteFile" => %{
                 "result" => file
               }
             }
           } = result

    refute Map.get(result, :errors)
    assert file

    file
  end
end
