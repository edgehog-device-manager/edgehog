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

defmodule EdgehogWeb.Schema.Mutation.UpdateDeviceTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase

  import Edgehog.AstarteFixtures

  describe "updateDevice field" do
    setup do
      device =
        cluster_fixture()
        |> realm_fixture()
        |> device_fixture()

      {:ok, device: device}
    end

    @query """
    mutation UpdateDevice($input: UpdateDeviceInput!) {
      updateDevice(input: $input) {
        device {
          id
          name
        }
      }
    }
    """
    test "updates device with valid data", %{
      conn: conn,
      api_path: api_path,
      device: device
    } do
      variables = %{
        input: %{
          device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema),
          name: "Some new name"
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateDevice" => %{
                   "device" => %{
                     "name" => "Some new name"
                   }
                 }
               }
             } = json_response(conn, 200)
    end

    test "fails with invalid data", %{conn: conn, api_path: api_path, device: device} do
      variables = %{
        input: %{
          device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema),
          # empty name
          name: ""
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end
  end
end
