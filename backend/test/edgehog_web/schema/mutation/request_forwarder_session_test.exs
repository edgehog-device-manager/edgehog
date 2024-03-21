#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.RequestForwarderSessionTest do
  use EdgehogWeb.ConnCase, async: true
  use Edgehog.AstarteMockCase

  alias Edgehog.Astarte.Device.ForwarderSession

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  describe "requestForwarderSession mutation" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      {:ok, realm: realm}
    end

    @query """
    mutation ($input: RequestForwarderSessionInput!) {
      requestForwarderSession(input: $input) {
        sessionToken
      }
    }
    """

    test "returns the token of a :connected session instead of a :connecting one", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      device = device_fixture(realm, %{online: true})

      mock_forwarder_sessions(device, [
        %ForwarderSession{
          token: "connecting_session_token",
          status: :connecting,
          secure: false,
          forwarder_hostname: "localhost",
          forwarder_port: 4001
        },
        %ForwarderSession{
          token: "connected_session_token",
          status: :connected,
          secure: false,
          forwarder_hostname: "localhost",
          forwarder_port: 4001
        }
      ])

      variables = %{
        input: %{
          device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema)
        }
      }

      result = run_query(conn, api_path, variables)

      assert %{
               "data" => %{
                 "requestForwarderSession" => %{
                   "sessionToken" => "connected_session_token"
                 }
               }
             } = result
    end

    test "returns the token of a :connecting session, if there are no :connected sessions", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      device = device_fixture(realm, %{online: true})

      mock_forwarder_sessions(device, [
        %ForwarderSession{
          token: "connecting_session_token_1",
          status: :connecting,
          secure: false,
          forwarder_hostname: "localhost",
          forwarder_port: 4001
        },
        %ForwarderSession{
          token: "connecting_session_token_2",
          status: :connecting,
          secure: false,
          forwarder_hostname: "localhost",
          forwarder_port: 4001
        }
      ])

      variables = %{
        input: %{
          device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema)
        }
      }

      result = run_query(conn, api_path, variables)

      assert %{
               "data" => %{
                 "requestForwarderSession" => %{
                   "sessionToken" => "connecting_session_token_1"
                 }
               }
             } = result
    end

    test "returns the token of a new session, if there is no available session", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      device = device_fixture(realm, %{online: true})
      mock_forwarder_sessions(device, [])

      variables = %{
        input: %{
          device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema)
        }
      }

      result = run_query(conn, api_path, variables)

      assert %{
               "data" => %{
                 "requestForwarderSession" => %{
                   "sessionToken" => session_token
                 }
               }
             } = result

      assert {:ok, ^session_token} = Ecto.UUID.cast(session_token)
    end

    test "returns error if the device is disconnected", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      device = device_fixture(realm, %{online: false})

      variables = %{
        input: %{
          device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema)
        }
      }

      result = run_query(conn, api_path, variables)

      assert %{
               "data" => %{
                 "requestForwarderSession" => nil
               },
               "errors" => [
                 %{
                   "code" => "device_disconnected",
                   "message" => "The device is not connected",
                   "status_code" => 409
                 }
               ]
             } = result
    end
  end

  defp mock_forwarder_sessions(device, forwarder_sessions) do
    device_id = device.device_id

    Edgehog.Astarte.Device.ForwarderSessionMock
    |> expect(:list_sessions, fn _appengine_client, ^device_id ->
      {:ok, forwarder_sessions}
    end)
  end

  defp run_query(conn, api_path, variables) do
    conn
    |> post(api_path, query: @query, variables: variables)
    |> json_response(200)
  end
end
