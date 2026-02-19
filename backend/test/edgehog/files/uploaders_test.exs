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

defmodule Edgehog.Files.UploadersTest do
  use ExUnit.Case, async: true

  alias Edgehog.Files.Uploaders

  describe "File uploader" do
    test "validates all files" do
      upload = %Plug.Upload{path: "/tmp/test.bin", filename: "test.bin"}
      assert Uploaders.File.validate({upload, %{}}) == true
    end

    test "storage_dir includes tenant and files directory" do
      scope = %{tenant_id: "tenant-123", file_name: "myfile.bin", repository_id: "repo-456"}

      dir = Uploaders.File.storage_dir(:original, {nil, scope})

      assert dir == "uploads/tenants/tenant-123/repositories/repo-456/files"
    end

    test "filename returns the file_name from scope" do
      scope = %{tenant_id: "tenant-123", file_name: "myfile.bin"}

      name = Uploaders.File.filename(:original, {nil, scope})

      assert name == "myfile.bin"
    end

    test "gcs_optional_params returns public read ACL" do
      params = Uploaders.File.gcs_optional_params(:original, {nil, %{}})

      assert params == [predefinedAcl: "publicRead"]
    end

    test "handles special characters in filenames" do
      scope = %{tenant_id: "tenant-123", file_name: "my file (1).bin"}

      name = Uploaders.File.filename(:original, {nil, scope})

      assert name == "my file (1).bin"
    end

    test "handles numeric tenant IDs" do
      scope = %{tenant_id: 456, file_name: "test.bin", repository_id: "repo-789"}

      dir = Uploaders.File.storage_dir(:original, {nil, scope})

      assert dir == "uploads/tenants/456/repositories/repo-789/files"
    end
  end
end
