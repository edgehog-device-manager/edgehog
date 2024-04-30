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
  use EdgehogWeb.GraphqlCase, async: true
  use Edgehog.AstarteMockCase

  alias Edgehog.Astarte.Device.ForwarderSession
  alias Edgehog.Astarte.Device.ForwarderSessionMock

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  @moduletag :ported_to_ash

  describe "requestForwarderSession mutation" do
    test "returns the token of a :connected session instead of a :connecting one", %{
      tenant: tenant
    } do
      device = device_fixture(online: true, tenant: tenant)
      device_id = device.device_id

      expect(ForwarderSessionMock, :list_sessions, fn _appengine_client, ^device_id ->
        {:ok,
         [
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
         ]}
      end)

      result = run_query(device_id: AshGraphql.Resource.encode_relay_id(device), tenant: tenant)

      assert "connected_session_token" = extract_result!(result)
    end

    test "returns the token of a :connecting session, if there are no :connected sessions", %{
      tenant: tenant
    } do
      device = device_fixture(online: true, tenant: tenant)
      device_id = device.device_id

      expect(ForwarderSessionMock, :list_sessions, fn _appengine_client, ^device_id ->
        {:ok,
         [
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
         ]}
      end)

      result = run_query(device_id: AshGraphql.Resource.encode_relay_id(device), tenant: tenant)

      assert "connecting_session_token_1" = extract_result!(result)
    end

    test "returns the token of a new session, if there is no available session", %{tenant: tenant} do
      device = device_fixture(online: true, tenant: tenant)
      device_id = device.device_id

      expect(ForwarderSessionMock, :list_sessions, fn _appengine_client, ^device_id ->
        {:ok, []}
      end)

      result = run_query(device_id: AshGraphql.Resource.encode_relay_id(device), tenant: tenant)

      assert session_token = extract_result!(result)

      assert {:ok, ^session_token} = Ecto.UUID.cast(session_token)
    end

    test "returns error if the device is disconnected", %{tenant: tenant} do
      device = device_fixture(online: false, tenant: tenant)
      device_id = device.id

      expect(ForwarderSessionMock, :list_sessions, 0, fn _appengine_client, ^device_id ->
        :unreachable
      end)

      result = run_query(device_id: AshGraphql.Resource.encode_relay_id(device), tenant: tenant)

      assert %{
               code: "invalid_argument",
               fields: [:device_id],
               message: "device is disconnected"
             } = extract_error!(result)
    end
  end

  defp run_query(opts) do
    document = """
    mutation ($input: RequestForwarderSessionInput!) {
      requestForwarderSession(input: $input)
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)
    device_id = Keyword.fetch!(opts, :device_id)

    variables = %{"input" => %{"deviceId" => device_id}}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_error!(result) do
    assert is_nil(result[:data]["requestForwarderSession"])
    assert %{errors: [error]} = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "requestForwarderSession" => session_token
             }
           } = result

    refute Map.get(result, :errors)

    assert session_token != nil

    session_token
  end
end
