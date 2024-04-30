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
  use EdgehogWeb.GraphqlCase, async: true
  use Edgehog.AstarteMockCase

  alias Edgehog.Astarte.Device.ForwarderSession
  alias Edgehog.Astarte.Device.ForwarderSessionMock

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  @moduletag :ported_to_ash

  describe "forwarderSession query" do
    test "returns the forwarder session", %{tenant: tenant} do
      device = device_fixture(online: true, tenant: tenant)
      device_id = device.device_id

      expect(ForwarderSessionMock, :list_sessions, fn _appengine_client, ^device_id ->
        {:ok,
         [
           %ForwarderSession{
             token: "session_token",
             status: :connected,
             secure: false,
             forwarder_hostname: "localhost",
             forwarder_port: 4001
           }
         ]}
      end)

      result =
        run_query(
          tenant: tenant,
          device_id: AshGraphql.Resource.encode_relay_id(device),
          session_token: "session_token"
        )

      assert %{
               "token" => "session_token",
               # TODO: Ash leaves atoms lowercase?
               "status" => "connected",
               "forwarderHostname" => "localhost",
               "forwarderPort" => 4001
             } = extract_result!(result)
    end

    test "returns null if the session does not exist", %{tenant: tenant} do
      device = device_fixture(online: true, tenant: tenant)
      device_id = device.device_id

      expect(ForwarderSessionMock, :list_sessions, fn _appengine_client, ^device_id ->
        {:ok, []}
      end)

      result =
        run_query(
          tenant: tenant,
          device_id: AshGraphql.Resource.encode_relay_id(device),
          session_token: "session_token"
        )

      forwarder_session = extract_result!(result)

      assert is_nil(forwarder_session)
    end

    test "returns null if the device is disconnected", %{tenant: tenant} do
      device = device_fixture(online: false, tenant: tenant)

      expect(ForwarderSessionMock, :list_sessions, 0, fn _appengine_client, _device_id ->
        :unreachable
      end)

      result =
        run_query(
          tenant: tenant,
          device_id: AshGraphql.Resource.encode_relay_id(device),
          session_token: "session_token"
        )

      forwarder_session = extract_result!(result)

      assert is_nil(forwarder_session)
    end
  end

  defp run_query(opts) do
    document = """
    query ($device_id: ID!, $session_token: String!) {
      forwarderSession(deviceId: $device_id, token: $session_token) {
        token
        status
        forwarderHostname
        forwarderPort
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    device_id = Keyword.fetch!(opts, :device_id)
    session_token = Keyword.fetch!(opts, :session_token)

    variables = %{
      "device_id" => device_id,
      "session_token" => session_token
    }

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert %{
             data: %{"forwarderSession" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "forwarderSession" => forwarder_session
             }
           } = result

    refute Map.get(result, :errors)

    forwarder_session
  end
end
