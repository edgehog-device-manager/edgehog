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

defmodule Edgehog.Files.BucketStorageTest do
  use ExUnit.Case, async: false

  alias Edgehog.Files.File, as: FileResource
  alias Edgehog.Files.File.BucketStorage, as: FileBucketStorage

  setup do
    # Create a unique temporary directory for this test run
    tmp_path =
      Path.join(System.tmp_dir!(), "edgehog-waffle-#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_path)

    # Backup original configuration
    previous_storage = Application.get_env(:waffle, :storage)

    # Force Waffle to use our temporary directory
    Application.put_env(:waffle, :storage, Waffle.Storage.Local)
    Application.put_env(:waffle, :storage_dir_prefix, tmp_path)

    on_exit(fn ->
      # Clean up the physical files and restore env
      File.rm_rf!(tmp_path)
      Application.put_env(:waffle, :storage, previous_storage)
      Application.put_env(:waffle, :storage_dir_prefix, nil)
    end)

    :ok
  end

  describe "file bucket storage" do
    test "store uploads and returns generated URL" do
      upload = create_upload("file-bucket-storage.bin")

      assert {:ok, file_url} =
               FileBucketStorage.store("tenant-file", "stored-file.bin", "repository-id", upload)

      assert file_url =~ "stored-file.bin"
    end

    test "delete removes file from storage" do
      upload = create_upload("file-bucket-storage-delete.bin")

      assert {:ok, file_url} =
               FileBucketStorage.store(
                 "tenant-file",
                 "stored-delete.bin",
                 "repository-id",
                 upload
               )

      file = %FileResource{
        name: "stored-delete.bin",
        tenant_id: "tenant-file",
        url: file_url
      }

      assert :ok = FileBucketStorage.delete(file)
    end
  end

  defp create_upload(filename) do
    path =
      Path.join(
        System.tmp_dir!(),
        "edgehog-upload-#{System.unique_integer([:positive])}-#{filename}"
      )

    File.write!(path, "bucket-storage-test")

    # Ensure the source file is also deleted after the test
    on_exit(fn -> File.rm(path) end)

    %Plug.Upload{
      path: path,
      filename: filename,
      content_type: "application/octet-stream"
    }
  end
end
