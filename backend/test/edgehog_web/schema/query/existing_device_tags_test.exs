#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.ExistingDeviceTagsTest do
  use EdgehogWeb.ConnCase

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Devices

  describe "existingDeviceTags field" do
    @query """
    {
      existingDeviceTags
    }
    """

    test "returns empty tags", %{conn: conn, api_path: api_path} do
      conn = get(conn, api_path, query: @query)

      assert json_response(conn, 200) == %{
               "data" => %{
                 "existingDeviceTags" => []
               }
             }
    end

    test "returns tags if they're present", %{conn: conn, api_path: api_path} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      tags = ["foo", "bar"]

      {:ok, _device} =
        device_fixture(realm)
        |> Devices.update_device(%{tags: tags})

      conn = get(conn, api_path, query: @query)

      assert %{
               "data" => %{
                 "existingDeviceTags" => tags
               }
             } == json_response(conn, 200)
    end

    test "return tags only if there're assigned to devices", %{conn: conn, api_path: api_path} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      {:ok, device} =
        device_fixture(realm)
        |> Devices.update_device(%{tags: ["foo", "bar"]})

      Devices.update_device(device, %{tags: ["bar"]})

      conn = get(conn, api_path, query: @query)

      assert %{
               "data" => %{
                 "existingDeviceTags" => ["bar"]
               }
             } == json_response(conn, 200)
    end
  end
end
