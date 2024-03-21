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

defmodule EdgehogWeb.Schema.Query.ForwarderSessionTest do
  use EdgehogWeb.ConnCase, async: true
  use Edgehog.AstarteMockCase

  alias Edgehog.Astarte.Device.ForwarderSession

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  describe "forwarderSession query" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      {:ok, realm: realm}
    end

    @query """
    query ($device_id: ID!, $session_token: String!) {
      forwarderSession(deviceId: $device_id, sessionToken: $session_token) {
        token
        status
        forwarderHostname
        forwarderPort
      }
    }
    """

    test "returns the forwarder session", %{conn: conn, api_path: api_path, realm: realm} do
      device = device_fixture(realm, %{online: true})

      mock_forwarder_session(device, "session_token", %ForwarderSession{
        token: "session_token",
        status: :connected,
        secure: false,
        forwarder_hostname: "localhost",
        forwarder_port: 4001
      })

      variables = %{
        device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema),
        session_token: "session_token"
      }

      result = run_query(conn, api_path, variables)

      assert %{
               "data" => %{
                 "forwarderSession" => %{
                   "token" => "session_token",
                   "status" => "CONNECTED",
                   "forwarderHostname" => "localhost",
                   "forwarderPort" => 4001
                 }
               }
             } = result
    end

    test "returns null if the session does not exist", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      device = device_fixture(realm, %{online: true})

      mock_forwarder_session(device, "session_token", nil)

      variables = %{
        device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema),
        session_token: "session_token"
      }

      result = run_query(conn, api_path, variables)

      assert %{
               "data" => %{
                 "forwarderSession" => nil
               }
             } = result
    end

    test "returns error if the device is disconnected", %{
      conn: conn,
      api_path: api_path,
      realm: realm
    } do
      device = device_fixture(realm, %{online: false})

      variables = %{
        device_id: Absinthe.Relay.Node.to_global_id(:device, device.id, EdgehogWeb.Schema),
        session_token: "session_token"
      }

      result = run_query(conn, api_path, variables)

      assert %{
               "data" => %{"forwarderSession" => nil},
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

  defp mock_forwarder_session(device, session_token, forwarder_session) do
    device_id = device.device_id

    Edgehog.Astarte.Device.ForwarderSessionMock
    |> expect(:fetch_session, fn _appengine_client, ^device_id, ^session_token ->
      if forwarder_session != nil do
        {:ok, forwarder_session}
      else
        {:error, :forwarder_session_not_found}
      end
    end)
  end

  defp run_query(conn, api_path, variables) do
    conn
    |> get(api_path, query: @query, variables: variables)
    |> json_response(200)
  end
end
