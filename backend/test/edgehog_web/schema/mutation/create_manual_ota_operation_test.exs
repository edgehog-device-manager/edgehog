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

defmodule EdgehogWeb.Schema.Mutation.CreateManualOTAOperationTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase
  use Edgehog.EphemeralImageMockCase

  import Edgehog.AstarteFixtures

  alias Edgehog.OSManagement
  alias Edgehog.OSManagement.OTAOperation

  describe "createManualOtaOperation field" do
    setup do
      device =
        cluster_fixture()
        |> realm_fixture()
        |> device_fixture()

      {:ok, device: device}
    end

    @query """
    mutation CreateManualOtaOperation($input: CreateManualOtaOperationInput!) {
      createManualOtaOperation(input: $input) {
        otaOperation {
          id
          baseImageUrl
          status
          createdAt
          updatedAt
          device {
            deviceId
          }
        }
      }
    }
    """
    test "creates OTA operation with valid data", %{conn: conn, device: device} do
      fake_image = %Plug.Upload{path: "test/fixtures/image.bin", filename: "image.bin"}

      variables = %{
        input: %{
          device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema),
          base_image_file: "fake_image"
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables, fake_image: fake_image)

      assert %{
               "data" => %{
                 "createManualOtaOperation" => %{
                   "otaOperation" => %{
                     "id" => id,
                     "baseImageUrl" => base_image_url,
                     "status" => "PENDING",
                     "createdAt" => _created_at,
                     "updatedAt" => _updated_at,
                     "device" => %{
                       "deviceId" => device_id
                     }
                   }
                 }
               }
             } = json_response(conn, 200)

      {:ok, %{type: :ota_operation, id: db_id}} =
        Absinthe.Relay.Node.from_global_id(id, EdgehogWeb.Schema)

      assert %OTAOperation{base_image_url: ^base_image_url} =
               OSManagement.get_ota_operation!(db_id)

      assert device.device_id == device_id
    end

    test "fails with invalid data", %{conn: conn} do
      variables = %{
        input: %{
          device_id: nil,
          base_image_file: nil
        }
      }

      conn = post(conn, "/api", query: @query, variables: variables)

      assert %{"errors" => _} = assert(json_response(conn, 200))
    end
  end
end
