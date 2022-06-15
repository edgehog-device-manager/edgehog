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

defmodule EdgehogWeb.Schema.Mutation.UpdateDeviceTest do
  use EdgehogWeb.ConnCase
  use Edgehog.AstarteMockCase

  import Edgehog.AstarteFixtures
  alias Edgehog.Astarte

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
          tags
          customAttributes {
            namespace
            key
            type
            value
          }
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
          name: "Some new name",
          tags: ["foo", "bar", "baz"],
          custom_attributes: %{
            namespace: "CUSTOM",
            key: "foo",
            type: "STRING",
            value: "bar"
          }
        }
      }

      conn = post(conn, api_path, query: @query, variables: variables)

      assert %{
               "data" => %{
                 "updateDevice" => %{
                   "device" => %{
                     "name" => "Some new name",
                     "tags" => ["foo", "bar", "baz"],
                     "customAttributes" => [
                       %{
                         "namespace" => "CUSTOM",
                         "key" => "foo",
                         "type" => "STRING",
                         "value" => "bar"
                       }
                     ]
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

    test "handles partial updates", %{
      conn: conn,
      api_path: api_path,
      device: device
    } do
      {:ok, _} =
        Astarte.update_device(device, %{
          tags: ["not", "touched"],
          custom_attributes: [
            %{
              namespace: :custom,
              key: "string",
              typed_value: %{
                type: :string,
                value: "not touched"
              }
            }
          ]
        })

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
                     "name" => "Some new name",
                     "tags" => ["not", "touched"],
                     "customAttributes" => [
                       %{
                         "namespace" => "CUSTOM",
                         "key" => "string",
                         "type" => "STRING",
                         "value" => "not touched"
                       }
                     ]
                   }
                 }
               }
             } = json_response(conn, 200)
    end
  end
end
