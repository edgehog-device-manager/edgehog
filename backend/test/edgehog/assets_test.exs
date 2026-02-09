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

defmodule Edgehog.AssetsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Edgehog.Assets
  alias Edgehog.Assets.SystemModelPictureMock

  setup :verify_on_exit!

  # Storage is disabled by default in test, but mock is configured
  # So the call goes through the mock
  describe "upload_system_model_picture/2" do
    test "returns {:ok, nil} when picture is nil" do
      assert {:ok, nil} = Assets.upload_system_model_picture(%{}, nil)
    end

    test "returns error when storage is disabled" do
      system_model = %{id: "123"}
      picture_file = %Plug.Upload{path: "/tmp/test.png", filename: "test.png"}

      stub(SystemModelPictureMock, :upload, fn _model, _file ->
        {:error, :mock_not_real}
      end)

      assert {:error, _reason} = Assets.upload_system_model_picture(system_model, picture_file)
    end
  end

  describe "delete_system_model_picture/2" do
    test "returns :ok when picture_url is nil" do
      assert :ok = Assets.delete_system_model_picture(%{}, nil)
    end

    test "returns error when storage is disabled" do
      system_model = %{id: "123"}
      picture_url = "https://example.com/picture.png"

      stub(SystemModelPictureMock, :delete, fn _model, _url ->
        {:error, :mock_not_real}
      end)

      assert {:error, _reason} = Assets.delete_system_model_picture(system_model, picture_url)
    end
  end
end
