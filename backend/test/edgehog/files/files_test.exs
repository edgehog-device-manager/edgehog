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

  alias Ash.Error.Invalid
  alias Edgehog.Files.File

  describe "File" do
    setup do
      tenant = tenant_fixture()
      %{tenant: tenant}
    end

    test "file_fixture/1 creates a file with default values", %{tenant: tenant} do
      file = file_fixture(tenant: tenant)

      assert %File{} = file
      assert file.name =~ "file-"
      assert file.size > 0
      assert file.digest =~ "sha256:"
      assert is_integer(file.mode)
      assert file.mode in [0o644, 0o755, 0o600, 0o664, 0o666]
      assert is_integer(file.user_id)
      assert file.user_id in [0, 999, 1000]
      assert is_integer(file.group_id)
      assert file.group_id in [0, 999, 1000]
      assert file.url =~ "https://example.com/files/"
    end

    test "file_fixture/1 creates a file with custom values", %{tenant: tenant} do
      file =
        file_fixture(
          tenant: tenant,
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

    test "read action returns all files for tenant", %{tenant: tenant} do
      file1 = file_fixture(tenant: tenant, name: "file1.bin")
      file2 = file_fixture(tenant: tenant, name: "file2.bin")

      files =
        File
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      file_ids = Enum.map(files, & &1.id)
      assert file1.id in file_ids
      assert file2.id in file_ids
    end

    test "destroy action deletes a file", %{tenant: tenant} do
      file = file_fixture(tenant: tenant)

      assert :ok = Ash.destroy!(file, tenant: tenant)

      files =
        File
        |> Ash.Query.for_read(:read)
        |> Ash.read!(tenant: tenant)

      refute Enum.any?(files, &(&1.id == file.id))
    end

    test "file requires name", %{tenant: tenant} do
      assert {:error, %Invalid{}} =
               File
               |> Ash.Changeset.for_create(:create, %{size: 100, digest: "sha256:abc"}, tenant: tenant)
               |> Ash.create()
    end

    test "file requires size", %{tenant: tenant} do
      assert {:error, %Invalid{}} =
               File
               |> Ash.Changeset.for_create(:create, %{name: "test.bin", digest: "sha256:abc"}, tenant: tenant)
               |> Ash.create()
    end

    test "file requires digest", %{tenant: tenant} do
      assert {:error, %Invalid{}} =
               File
               |> Ash.Changeset.for_create(:create, %{name: "test.bin", size: 100}, tenant: tenant)
               |> Ash.create()
    end

    test "file allows nil optional fields", %{tenant: tenant} do
      file =
        file_fixture(
          tenant: tenant,
          mode: nil,
          user_id: nil,
          group_id: nil,
          url: nil
        )

      assert file.mode == nil
      assert file.user_id == nil
      assert file.group_id == nil
      assert file.url == nil
    end

    test "creates executable file with proper permissions", %{tenant: tenant} do
      file =
        file_fixture(
          tenant: tenant,
          name: "script.sh",
          mode: file_mode(:executable),
          user_id: user_id(:regular),
          group_id: group_id(:regular)
        )

      assert file.name == "script.sh"
      assert file.mode == 0o755
      assert file.user_id == 1000
      assert file.group_id == 1000
    end

    test "creates private file readable only by owner", %{tenant: tenant} do
      file =
        file_fixture(
          tenant: tenant,
          name: "private.key",
          mode: file_mode(:private),
          user_id: user_id(:regular),
          group_id: group_id(:regular)
        )

      assert file.name == "private.key"
      assert file.mode == 0o600
      assert file.user_id == 1000
      assert file.group_id == 1000
    end

    test "creates system service file", %{tenant: tenant} do
      file =
        file_fixture(
          tenant: tenant,
          name: "service.conf",
          mode: file_mode(:regular),
          user_id: user_id(:system),
          group_id: group_id(:system)
        )

      assert file.name == "service.conf"
      assert file.mode == 0o644
      assert file.user_id == 999
      assert file.group_id == 999
    end

    test "creates shared writable file", %{tenant: tenant} do
      file =
        file_fixture(
          tenant: tenant,
          name: "shared.log",
          mode: file_mode(:shared_writable),
          user_id: user_id(:regular),
          group_id: group_id(:regular)
        )

      assert file.name == "shared.log"
      assert file.mode == 0o664
      assert file.user_id == 1000
      assert file.group_id == 1000
    end

    test "creates root-owned file", %{tenant: tenant} do
      file =
        file_fixture(
          tenant: tenant,
          name: "system.conf",
          mode: file_mode(:regular),
          user_id: user_id(:root),
          group_id: group_id(:root)
        )

      assert file.name == "system.conf"
      assert file.mode == 0o644
      assert file.user_id == 0
      assert file.group_id == 0
    end

    test "file_mode/1 returns correct permissions for each type", %{tenant: _tenant} do
      assert file_mode() == 0o644
      assert file_mode(:regular) == 0o644
      assert file_mode(:executable) == 0o755
      assert file_mode(:private) == 0o600
      assert file_mode(:shared_writable) == 0o664
      assert file_mode(:world_writable) == 0o666
    end

    test "user_id/1 returns correct UID for each type", %{tenant: _tenant} do
      assert user_id() == 0
      assert user_id(:root) == 0
      assert user_id(:regular) == 1000
      assert user_id(:system) == 999
    end

    test "group_id/1 returns correct GID for each type", %{tenant: _tenant} do
      assert group_id() == 0
      assert group_id(:root) == 0
      assert group_id(:regular) == 1000
      assert group_id(:system) == 999
    end
  end
end
