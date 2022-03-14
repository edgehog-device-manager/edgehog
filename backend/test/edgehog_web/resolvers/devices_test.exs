#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule EdgehogWeb.Resolvers.DevicesTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AssetsStoreMockCase

  alias EdgehogWeb.Resolvers.Devices

  import Edgehog.DevicesFixtures

  describe "system_models" do
    setup %{tenant: tenant} do
      context = %{current_tenant: tenant}

      {:ok, context: context}
    end

    test "create_system_model/3 stores the picture_file", %{context: context} do
      hardware_type = hardware_type_fixture()

      name = "Foobar"
      handle = "foobar"
      part_number = "12345/X"

      attrs = %{
        name: name,
        handle: handle,
        part_numbers: [part_number],
        hardware_type_id: hardware_type.id,
        picture_file: %Plug.Upload{filename: "foo.jpg"}
      }

      assert {:ok, %{system_model: system_model}} =
               Devices.create_system_model(%{}, attrs, %{context: context})

      assert String.starts_with?(system_model.picture_url, "http")
      assert String.ends_with?(system_model.picture_url, "foo.jpg")
    end

    test "create_system_model/3 saves the picture_url", %{context: context} do
      hardware_type = hardware_type_fixture()

      name = "Foobar"
      handle = "foobar"
      part_number = "12345/X"

      attrs = %{
        name: name,
        handle: handle,
        part_numbers: [part_number],
        hardware_type_id: hardware_type.id,
        picture_url: "https://domain.com/foo.jpg"
      }

      assert {:ok, %{system_model: system_model}} =
               Devices.create_system_model(%{}, attrs, %{context: context})

      assert system_model.picture_url == "https://domain.com/foo.jpg"
    end

    test "create_system_model/3 prefers saving picture_file over picture_url", %{
      context: context
    } do
      hardware_type = hardware_type_fixture()

      name = "Foobar"
      handle = "foobar"
      part_number = "12345/X"

      attrs = %{
        name: name,
        handle: handle,
        part_numbers: [part_number],
        hardware_type_id: hardware_type.id,
        picture_url: "https://domain.com/foo.jpg",
        picture_file: %Plug.Upload{filename: "bar.jpg"}
      }

      assert {:ok, %{system_model: system_model}} =
               Devices.create_system_model(%{}, attrs, %{context: context})

      assert String.ends_with?(system_model.picture_url, "bar.jpg")
    end

    test "update_system_model/3 changes the picture by storing picture_file", %{
      context: context
    } do
      hardware_type = hardware_type_fixture()
      system_model = system_model_fixture(hardware_type, %{picture_url: nil})

      attrs = %{
        system_model_id: system_model.id,
        picture_file: %Plug.Upload{filename: "foo.jpg"}
      }

      assert {:ok, %{system_model: am}} =
               Devices.update_system_model(%{}, attrs, %{context: context})

      assert String.starts_with?(am.picture_url, "http")
      assert String.ends_with?(am.picture_url, "foo.jpg")
    end

    test "update_system_model/3 changes the picture with picture_url", %{context: context} do
      hardware_type = hardware_type_fixture()
      system_model = system_model_fixture(hardware_type, %{picture_url: nil})

      attrs = %{
        system_model_id: system_model.id,
        picture_url: "https://domain.com/foo.jpg"
      }

      assert {:ok, %{system_model: am}} =
               Devices.update_system_model(%{}, attrs, %{context: context})

      assert am.picture_url == "https://domain.com/foo.jpg"
    end

    test "update_system_model/3 prefers saving picture_file over picture_url", %{
      context: context
    } do
      hardware_type = hardware_type_fixture()
      system_model = system_model_fixture(hardware_type, %{picture_url: nil})

      attrs = %{
        system_model_id: system_model.id,
        picture_url: "https://domain.com/foo.jpg",
        picture_file: %Plug.Upload{filename: "bar.jpg"}
      }

      assert {:ok, %{system_model: am}} =
               Devices.update_system_model(%{}, attrs, %{context: context})

      assert String.ends_with?(am.picture_url, "bar.jpg")
    end

    test "update_system_model/3 removes the picture when picture_url is set to null", %{
      context: context
    } do
      hardware_type = hardware_type_fixture()

      system_model =
        system_model_fixture(hardware_type, %{picture_url: "https://domain.com/foo.jpg"})

      attrs = %{
        system_model_id: system_model.id,
        picture_url: nil
      }

      assert {:ok, %{system_model: am}} =
               Devices.update_system_model(%{}, attrs, %{context: context})

      assert is_nil(am.picture_url)
    end

    test "update_system_model/3 does not remove the picture when picture_file is set to null",
         %{
           context: context
         } do
      hardware_type = hardware_type_fixture()

      system_model =
        system_model_fixture(hardware_type, %{picture_url: "https://domain.com/foo.jpg"})

      attrs = %{
        system_model_id: system_model.id,
        picture_file: nil
      }

      assert {:ok, %{system_model: am}} =
               Devices.update_system_model(%{}, attrs, %{context: context})

      assert am.picture_url == "https://domain.com/foo.jpg"
    end

    test "update_system_model/3 does not change the picture when not specified", %{
      context: context
    } do
      hardware_type = hardware_type_fixture()

      system_model =
        system_model_fixture(hardware_type, %{picture_url: "https://domain.com/foo.jpg"})

      # Picture field not specified in the update attrs
      attrs = %{
        system_model_id: system_model.id
      }

      assert {:ok, %{system_model: am}} =
               Devices.update_system_model(%{}, attrs, %{context: context})

      assert am.picture_url == "https://domain.com/foo.jpg"
    end

    test "update_system_model/3 does not store the picture file if other changes are invalid",
         %{context: context} do
      hardware_type = hardware_type_fixture()
      system_model = system_model_fixture(hardware_type, %{picture_url: nil})

      attrs = %{
        system_model_id: system_model.id,
        handle: "Invalid handle!",
        picture_file: %Plug.Upload{filename: "foo.jpg"}
      }

      # Set expection on :store to be called 0 times, will be verified on test exit
      Edgehog.Assets.SystemModelPictureMock
      |> expect(:upload, 0, fn _, _ -> throw("Picture stored") end)

      Devices.update_system_model(%{}, attrs, %{context: context})
    end
  end
end
