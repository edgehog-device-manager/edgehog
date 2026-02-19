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

defmodule Edgehog.FilesTest do
  use Edgehog.DataCase, async: true

  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Files.File, as: FileResource
  alias Edgehog.Files.StorageMock

  describe "File create via fixture" do
    setup do
      tenant = tenant_fixture()
      repository = repository_fixture(tenant: tenant)
      %{tenant: tenant, repository: repository}
    end

    test "creates a file with generated defaults", %{tenant: tenant, repository: repository} do
      file = file_fixture(tenant: tenant, repository_id: repository.id)

      assert %FileResource{} = file
      assert file.name =~ "file-"
      assert file.size > 0
      assert file.digest =~ "sha256:"
      assert is_integer(file.mode)
      assert is_integer(file.user_id)
      assert is_integer(file.group_id)
      assert file.url =~ "https://example.com/files/"
      assert file.repository_id == repository.id
    end

    test "creates a file with custom attributes", %{tenant: tenant, repository: repository} do
      file =
        file_fixture(
          tenant: tenant,
          repository_id: repository.id,
          name: "custom-file.tar.gz",
          size: 12_345,
          digest: "sha256:abc123",
          mode: 0o755,
          user_id: 1000,
          group_id: 1000,
          url: "https://my-bucket.s3.amazonaws.com/custom-file.tar.gz"
        )

      assert file.name == "custom-file.tar.gz"
      assert file.size == 12_345
      assert file.digest == "sha256:abc123"
      assert file.mode == 0o755
      assert file.user_id == 1000
      assert file.group_id == 1000
      assert file.url == "https://my-bucket.s3.amazonaws.com/custom-file.tar.gz"
    end

    test "auto-creates repository when not provided", %{tenant: tenant} do
      file = file_fixture(tenant: tenant)
      assert %FileResource{} = file
      assert file.repository_id
    end

    test "allows nil for optional fields", %{tenant: tenant, repository: repository} do
      file =
        file_fixture(
          tenant: tenant,
          repository_id: repository.id,
          mode: nil,
          user_id: nil,
          group_id: nil,
          url: nil
        )

      assert is_nil(file.mode)
      assert is_nil(file.user_id)
      assert is_nil(file.group_id)
      assert is_nil(file.url)
    end
  end

  describe "File read" do
    setup do
      tenant = tenant_fixture()
      repository = repository_fixture(tenant: tenant)
      %{tenant: tenant, repository: repository}
    end

    test "lists files for a tenant", %{tenant: tenant, repository: repository} do
      file1 = file_fixture(tenant: tenant, repository_id: repository.id, name: "a.bin")
      file2 = file_fixture(tenant: tenant, repository_id: repository.id, name: "b.bin")

      files =
        FileResource
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      ids = Enum.map(files, & &1.id)
      assert file1.id in ids
      assert file2.id in ids
    end

    test "does not leak files across tenants" do
      tenant_a = tenant_fixture()
      tenant_b = tenant_fixture()

      file_a = file_fixture(tenant: tenant_a)
      _file_b = file_fixture(tenant: tenant_b)

      files =
        FileResource
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant_a)

      ids = Enum.map(files, & &1.id)
      assert file_a.id in ids
      assert length(ids) == 1
    end
  end

  describe "File destroy via destroy_fixture" do
    setup do
      tenant = tenant_fixture()
      repository = repository_fixture(tenant: tenant)
      file_record = file_fixture(tenant: tenant, repository_id: repository.id)
      %{tenant: tenant, file_record: file_record}
    end

    test "removes the file record", %{tenant: tenant, file_record: file_record} do
      assert :ok =
               file_record
               |> Ash.Changeset.for_destroy(:destroy_fixture)
               |> Ash.destroy!(tenant: tenant)

      files =
        FileResource
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      refute Enum.any?(files, &(&1.id == file_record.id))
    end
  end

  describe "File attribute defaults" do
    setup do
      tenant = tenant_fixture()
      repository = repository_fixture(tenant: tenant)
      %{tenant: tenant, repository: repository}
    end

    test "mode defaults to 0o644", %{tenant: tenant, repository: repository} do
      file =
        FileResource
        |> Ash.Changeset.for_create(
          :create_fixture,
          %{
            name: "defaults.bin",
            size: 1,
            digest: "sha256:abc",
            repository_id: repository.id
          },
          tenant: tenant
        )
        |> Ash.create!()

      assert file.mode == 0o644
    end

    test "user_id defaults to 0", %{tenant: tenant, repository: repository} do
      file =
        FileResource
        |> Ash.Changeset.for_create(
          :create_fixture,
          %{
            name: "defaults.bin",
            size: 1,
            digest: "sha256:abc",
            repository_id: repository.id
          },
          tenant: tenant
        )
        |> Ash.create!()

      assert file.user_id == 0
    end

    test "group_id defaults to 0", %{tenant: tenant, repository: repository} do
      file =
        FileResource
        |> Ash.Changeset.for_create(
          :create_fixture,
          %{
            name: "defaults.bin",
            size: 1,
            digest: "sha256:abc",
            repository_id: repository.id
          },
          tenant: tenant
        )
        |> Ash.create!()

      assert file.group_id == 0
    end
  end

  describe "File validation" do
    setup do
      tenant = tenant_fixture()
      repository = repository_fixture(tenant: tenant)
      %{tenant: tenant, repository: repository}
    end

    test "name is required", %{tenant: tenant, repository: repository} do
      assert {:error, _} =
               FileResource
               |> Ash.Changeset.for_create(
                 :create_fixture,
                 %{size: 100, digest: "sha256:abc", repository_id: repository.id},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "size is required", %{tenant: tenant, repository: repository} do
      assert {:error, _} =
               FileResource
               |> Ash.Changeset.for_create(
                 :create_fixture,
                 %{name: "test.bin", digest: "sha256:abc", repository_id: repository.id},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "digest is required", %{tenant: tenant, repository: repository} do
      assert {:error, _} =
               FileResource
               |> Ash.Changeset.for_create(
                 :create_fixture,
                 %{name: "test.bin", size: 100, repository_id: repository.id},
                 tenant: tenant
               )
               |> Ash.create()
    end
  end

  describe "File create action with upload" do
    setup do
      tenant = tenant_fixture()
      repository = repository_fixture(tenant: tenant)
      %{tenant: tenant, repository: repository}
    end

    test "creates file, computes size/digest, stores to bucket", %{
      tenant: tenant,
      repository: repository
    } do
      content = "hello world"
      tmp_path = create_temp_file(content)
      upload = %Plug.Upload{path: tmp_path, filename: "test.bin"}

      expected_hash =
        :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

      expected_digest = "sha256:#{expected_hash}"

      Mox.expect(StorageMock, :store, fn _tenant_id, "test.bin", _repository_id, ^upload ->
        {:ok, "https://bucket.example.com/test.bin"}
      end)

      file =
        FileResource
        |> Ash.Changeset.for_create(
          :create,
          %{name: "test.bin", repository_id: repository.id, file: upload},
          tenant: tenant
        )
        |> Ash.create!()

      assert file.name == "test.bin"
      assert file.url == "https://bucket.example.com/test.bin"
      assert file.size == byte_size(content)
      assert file.digest == expected_digest
      assert file.repository_id == repository.id
      # defaults applied
      assert file.mode == 0o644
      assert file.user_id == 0
      assert file.group_id == 0
    end

    test "creates file with custom mode/user_id/group_id", %{
      tenant: tenant,
      repository: repository
    } do
      tmp_path = create_temp_file("data")
      upload = %Plug.Upload{path: tmp_path, filename: "script.sh"}

      Mox.expect(StorageMock, :store, fn _, _, _, _ ->
        {:ok, "https://bucket.example.com/script.sh"}
      end)

      file =
        FileResource
        |> Ash.Changeset.for_create(
          :create,
          %{
            name: "script.sh",
            repository_id: repository.id,
            file: upload,
            mode: 0o755,
            user_id: 1000,
            group_id: 1000
          },
          tenant: tenant
        )
        |> Ash.create!()

      assert file.mode == 0o755
      assert file.user_id == 1000
      assert file.group_id == 1000
    end

    test "returns error when storage fails", %{tenant: tenant, repository: repository} do
      tmp_path = create_temp_file("data")
      upload = %Plug.Upload{path: tmp_path, filename: "fail.bin"}

      Mox.expect(StorageMock, :store, fn _, _, _, _ ->
        {:error, :storage_unavailable}
      end)

      assert {:error, _} =
               FileResource
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "fail.bin", repository_id: repository.id, file: upload},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "requires file argument", %{tenant: tenant, repository: repository} do
      assert {:error, _} =
               FileResource
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "no-file.bin", repository_id: repository.id},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "requires repository_id argument", %{tenant: tenant} do
      tmp_path = create_temp_file("data")
      upload = %Plug.Upload{path: tmp_path, filename: "orphan.bin"}

      assert {:error, _} =
               FileResource
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "orphan.bin", file: upload},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "computes correct SHA256 digest for binary content", %{
      tenant: tenant,
      repository: repository
    } do
      # Use content with known SHA256
      content = String.duplicate("A", 4096)
      tmp_path = create_temp_file(content)
      upload = %Plug.Upload{path: tmp_path, filename: "large.bin"}

      expected_hash =
        :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

      Mox.expect(StorageMock, :store, fn _, _, _, _ ->
        {:ok, "https://bucket.example.com/large.bin"}
      end)

      file =
        FileResource
        |> Ash.Changeset.for_create(
          :create,
          %{name: "large.bin", repository_id: repository.id, file: upload},
          tenant: tenant
        )
        |> Ash.create!()

      assert file.digest == "sha256:#{expected_hash}"
      assert file.size == byte_size(content)
    end

    test "computes correct digest for empty file", %{tenant: tenant, repository: repository} do
      tmp_path = create_temp_file("")
      upload = %Plug.Upload{path: tmp_path, filename: "empty.bin"}

      expected_hash =
        :sha256 |> :crypto.hash("") |> Base.encode16(case: :lower)

      Mox.expect(StorageMock, :store, fn _, _, _, _ ->
        {:ok, "https://bucket.example.com/empty.bin"}
      end)

      file =
        FileResource
        |> Ash.Changeset.for_create(
          :create,
          %{name: "empty.bin", repository_id: repository.id, file: upload},
          tenant: tenant
        )
        |> Ash.create!()

      assert file.digest == "sha256:#{expected_hash}"
      assert file.size == 0
    end
  end

  describe "File destroy action (primary)" do
    setup do
      tenant = tenant_fixture()
      repository = repository_fixture(tenant: tenant)
      file_record = file_fixture(tenant: tenant, repository_id: repository.id)
      %{tenant: tenant, file_record: file_record}
    end

    test "deletes file and calls storage delete", %{tenant: tenant, file_record: file_record} do
      Mox.expect(StorageMock, :delete, fn deleted_file ->
        assert deleted_file.id == file_record.id
        :ok
      end)

      assert :ok = Ash.destroy!(file_record, tenant: tenant, action: :destroy)

      files =
        FileResource
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      refute Enum.any?(files, &(&1.id == file_record.id))
    end

    test "still deletes record even when storage delete fails", %{
      tenant: tenant,
      file_record: file_record
    } do
      Mox.expect(StorageMock, :delete, fn _file ->
        {:error, :not_found}
      end)

      assert :ok = Ash.destroy!(file_record, tenant: tenant, action: :destroy)

      files =
        FileResource
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      refute Enum.any?(files, &(&1.id == file_record.id))
    end
  end

  describe "File-Repository relationship" do
    setup do
      tenant = tenant_fixture()
      %{tenant: tenant}
    end

    test "file belongs to the specified repository", %{tenant: tenant} do
      repo = repository_fixture(tenant: tenant)
      file = file_fixture(tenant: tenant, repository_id: repo.id)

      assert file.repository_id == repo.id
    end

    test "files from different repos are independent", %{tenant: tenant} do
      repo_a = repository_fixture(tenant: tenant)
      repo_b = repository_fixture(tenant: tenant)

      file_a = file_fixture(tenant: tenant, repository_id: repo_a.id, name: "a.bin")
      file_b = file_fixture(tenant: tenant, repository_id: repo_b.id, name: "b.bin")

      assert file_a.repository_id == repo_a.id
      assert file_b.repository_id == repo_b.id
      assert file_a.repository_id != file_b.repository_id
    end

    test "multiple files in same repository", %{tenant: tenant} do
      repo = repository_fixture(tenant: tenant)
      file1 = file_fixture(tenant: tenant, repository_id: repo.id, name: "one.bin")
      file2 = file_fixture(tenant: tenant, repository_id: repo.id, name: "two.bin")

      files =
        FileResource
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)
        |> Enum.filter(&(&1.repository_id == repo.id))

      ids = Enum.map(files, & &1.id)
      assert file1.id in ids
      assert file2.id in ids
    end
  end

  describe "fixture helpers" do
    test "file_mode/1 returns correct permissions" do
      assert file_mode() == 0o644
      assert file_mode(:regular) == 0o644
      assert file_mode(:executable) == 0o755
      assert file_mode(:private) == 0o600
      assert file_mode(:shared_writable) == 0o664
      assert file_mode(:world_writable) == 0o666
    end

    test "user_id/1 returns correct UIDs" do
      assert user_id() == 0
      assert user_id(:root) == 0
      assert user_id(:regular) == 1000
      assert user_id(:system) == 999
    end

    test "group_id/1 returns correct GIDs" do
      assert group_id() == 0
      assert group_id(:root) == 0
      assert group_id(:regular) == 1000
      assert group_id(:system) == 999
    end

    test "unique_file_name/0 generates unique names" do
      name1 = unique_file_name()
      name2 = unique_file_name()
      assert name1 != name2
      assert name1 =~ ~r/^file-\d+\.bin$/
    end

    test "unique_file_digest/0 generates valid sha256 digests" do
      digest1 = unique_file_digest()
      digest2 = unique_file_digest()
      assert digest1 != digest2
      assert digest1 =~ ~r/^sha256:[a-f0-9]{64}$/
    end

    test "unique_repository_name/0 generates unique names" do
      name1 = unique_repository_name()
      name2 = unique_repository_name()
      assert name1 != name2
      assert name1 =~ ~r/^Repository \d+$/
    end

    test "unique_repository_handle/0 generates unique handles" do
      handle1 = unique_repository_handle()
      handle2 = unique_repository_handle()
      assert handle1 != handle2
      assert handle1 =~ ~r/^repo-\d+$/
    end
  end

  defp create_temp_file(content) do
    path =
      Path.join(
        System.tmp_dir!(),
        "edgehog_test_upload_#{System.unique_integer([:positive])}"
      )

    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
