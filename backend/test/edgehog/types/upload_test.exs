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

defmodule Edgehog.Types.UploadTest do
  use ExUnit.Case, async: true

  alias Edgehog.Types.Upload

  describe "graphql_input_type/1" do
    test "returns :upload" do
      assert Upload.graphql_input_type(nil) == :upload
    end
  end

  describe "storage_type/1" do
    test "returns :term" do
      assert Upload.storage_type(nil) == :term
    end
  end

  describe "cast_input/2" do
    test "casts nil to nil" do
      assert Upload.cast_input(nil, []) == {:ok, nil}
    end

    test "casts Plug.Upload struct" do
      upload = %Plug.Upload{
        path: "/tmp/test.txt",
        filename: "test.txt",
        content_type: "text/plain"
      }

      assert Upload.cast_input(upload, []) == {:ok, upload}
    end

    test "returns error for invalid input" do
      assert Upload.cast_input("invalid", []) == :error
      assert Upload.cast_input(123, []) == :error
      assert Upload.cast_input(%{}, []) == :error
    end
  end

  describe "cast_stored/2" do
    test "casts nil to nil" do
      assert Upload.cast_stored(nil, []) == {:ok, nil}
    end

    test "casts Plug.Upload struct" do
      upload = %Plug.Upload{
        path: "/tmp/test.txt",
        filename: "test.txt",
        content_type: "text/plain"
      }

      assert Upload.cast_stored(upload, []) == {:ok, upload}
    end

    test "returns error for invalid input" do
      assert Upload.cast_stored("invalid", []) == :error
      assert Upload.cast_stored(123, []) == :error
      assert Upload.cast_stored(%{}, []) == :error
    end
  end

  describe "dump_to_native/2" do
    test "dumps nil to nil" do
      assert Upload.dump_to_native(nil, []) == {:ok, nil}
    end

    test "returns error for any non-nil value" do
      upload = %Plug.Upload{
        path: "/tmp/test.txt",
        filename: "test.txt",
        content_type: "text/plain"
      }

      assert Upload.dump_to_native(upload, []) == :error
      assert Upload.dump_to_native("something", []) == :error
    end
  end
end
