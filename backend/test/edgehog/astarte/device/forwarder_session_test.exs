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

defmodule Edgehog.Astarte.Device.ForwarderSessionTest do
  use Edgehog.DataCase, async: true

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.ForwarderSession

  describe "forwarder_session" do
    import Edgehog.AstarteFixtures
    import Tesla.Mock

    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)
      device = astarte_device_fixture(realm)

      {:ok, appengine_client} =
        AppEngine.new(cluster.base_api_url, realm.name, private_key: realm.private_key)

      {:ok, cluster: cluster, realm: realm, device: device, appengine_client: appengine_client}
    end

    test "list_sessions/2 correctly parses session states data", %{
      device: device,
      appengine_client: appengine_client
    } do
      response = %{
        "data" => %{
          "session_token_1" => %{
            "status" => "Connecting"
          },
          "session_token_2" => %{
            "status" => "Connected"
          }
        }
      }

      mock(fn
        %{method: :get, url: _api_url} ->
          json(response)
      end)

      assert {:ok, sessions} =
               ForwarderSession.list_sessions(appengine_client, device.device_id)

      assert sessions == [
               %ForwarderSession{
                 token: "session_token_1",
                 status: :connecting,
                 secure: false,
                 forwarder_hostname: "localhost",
                 forwarder_port: 4001
               },
               %ForwarderSession{
                 token: "session_token_2",
                 status: :connected,
                 secure: false,
                 forwarder_hostname: "localhost",
                 forwarder_port: 4001
               }
             ]
    end
  end
end
