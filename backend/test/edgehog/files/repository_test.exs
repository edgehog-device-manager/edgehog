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

defmodule Edgehog.RepositoryTest do
  use Edgehog.DataCase, async: true

  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Files.File, as: FileResource
  alias Edgehog.Files.Repository

  describe "Repository create" do
    setup do
      %{tenant: tenant_fixture()}
    end

    test "creates a repository with valid params", %{tenant: tenant} do
      repo = repository_fixture(tenant: tenant)
      assert %Repository{} = repo
      assert repo.name =~ "Repository"
      assert repo.handle =~ "repo-"
      assert is_nil(repo.description)
    end

    test "creates a repository with all params including description", %{tenant: tenant} do
      repo =
        repository_fixture(
          tenant: tenant,
          name: "Firmware Images",
          handle: "firmware-images",
          description: "Stores firmware blobs"
        )

      assert repo.name == "Firmware Images"
      assert repo.handle == "firmware-images"
      assert repo.description == "Stores firmware blobs"
    end

    test "fails without name", %{tenant: tenant} do
      assert {:error, _} =
               Repository
               |> Ash.Changeset.for_create(:create, %{handle: "some-handle"}, tenant: tenant)
               |> Ash.create()
    end

    test "fails without handle", %{tenant: tenant} do
      assert {:error, _} =
               Repository
               |> Ash.Changeset.for_create(:create, %{name: "Some Name"}, tenant: tenant)
               |> Ash.create()
    end

    test "enforces unique name per tenant", %{tenant: tenant} do
      repository_fixture(tenant: tenant, name: "Unique Name")

      assert {:error, _} =
               Repository
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Unique Name", handle: "different-handle"},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "enforces unique handle per tenant", %{tenant: tenant} do
      repository_fixture(tenant: tenant, handle: "unique-handle")

      assert {:error, _} =
               Repository
               |> Ash.Changeset.for_create(
                 :create,
                 %{name: "Different Name", handle: "unique-handle"},
                 tenant: tenant
               )
               |> Ash.create()
    end

    test "allows same name in different tenants" do
      tenant_a = tenant_fixture()
      tenant_b = tenant_fixture()

      assert %Repository{} =
               repository_fixture(tenant: tenant_a, name: "Shared Name", handle: "handle-a")

      assert %Repository{} =
               repository_fixture(tenant: tenant_b, name: "Shared Name", handle: "handle-b")
    end
  end

  describe "Repository read" do
    setup do
      tenant = tenant_fixture()
      %{tenant: tenant}
    end

    test "lists all repositories for a tenant", %{tenant: tenant} do
      repo1 = repository_fixture(tenant: tenant)
      repo2 = repository_fixture(tenant: tenant)

      repos =
        Repository
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      ids = Enum.map(repos, & &1.id)
      assert repo1.id in ids
      assert repo2.id in ids
    end

    test "does not leak across tenants" do
      tenant_a = tenant_fixture()
      tenant_b = tenant_fixture()

      repo_a = repository_fixture(tenant: tenant_a)
      _repo_b = repository_fixture(tenant: tenant_b)

      repos =
        Repository
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant_a)

      ids = Enum.map(repos, & &1.id)
      assert repo_a.id in ids
      assert length(ids) == 1
    end
  end

  describe "Repository update" do
    setup do
      tenant = tenant_fixture()
      repo = repository_fixture(tenant: tenant)
      %{tenant: tenant, repository: repo}
    end

    test "updates name", %{tenant: tenant, repository: repo} do
      updated =
        repo
        |> Ash.Changeset.for_update(:update, %{name: "Updated Name"}, tenant: tenant)
        |> Ash.update!()

      assert updated.name == "Updated Name"
      assert updated.handle == repo.handle
    end

    test "updates handle", %{tenant: tenant, repository: repo} do
      updated =
        repo
        |> Ash.Changeset.for_update(:update, %{handle: "updated-handle"}, tenant: tenant)
        |> Ash.update!()

      assert updated.handle == "updated-handle"
    end

    test "updates description", %{tenant: tenant, repository: repo} do
      updated =
        repo
        |> Ash.Changeset.for_update(:update, %{description: "New description"}, tenant: tenant)
        |> Ash.update!()

      assert updated.description == "New description"
    end

    test "clears description with nil", %{tenant: tenant} do
      repo = repository_fixture(tenant: tenant, description: "has a description")

      updated =
        repo
        |> Ash.Changeset.for_update(:update, %{description: nil}, tenant: tenant)
        |> Ash.update!()

      assert is_nil(updated.description)
    end
  end

  describe "Repository destroy" do
    setup do
      tenant = tenant_fixture()
      repo = repository_fixture(tenant: tenant)
      %{tenant: tenant, repository: repo}
    end

    test "destroys the repository", %{tenant: tenant, repository: repo} do
      assert :ok = Ash.destroy!(repo, tenant: tenant)

      repos =
        Repository
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      refute Enum.any?(repos, &(&1.id == repo.id))
    end

    test "cascade-deletes associated files at DB level", %{tenant: tenant, repository: repo} do
      file_fixture(tenant: tenant, repository_id: repo.id)
      file_fixture(tenant: tenant, repository_id: repo.id)

      assert :ok = Ash.destroy!(repo, tenant: tenant)

      files =
        FileResource
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      assert files == []
    end
  end

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
end
