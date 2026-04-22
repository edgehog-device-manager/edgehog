#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Controllers.AstarteTriggerController.DeploymentEventsTest do
  use EdgehogWeb.ConnCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers.Deployment

  describe "deployment events" do
    setup %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)
      deployment = deployment_fixture(tenant: tenant, device_id: device.id)

      {:ok, cluster: cluster, realm: realm, device: device, deployment: deployment}
    end

    test "do not update the state", context do
      %{
        conn: conn,
        realm: realm,
        device: device,
        tenant: tenant,
        deployment: deployment
      } = context

      deployment_event = %{
        device_id: device.device_id,
        event: %{
          type: "incoming_data",
          interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
          path: "/" <> deployment.id,
          value: %{
            "status" => "Error",
            "message" => "error message"
          }
        },
        timestamp: DateTime.to_iso8601(DateTime.utc_now())
      }

      path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

      conn
      |> put_req_header("astarte-realm", realm.name)
      |> post(path, deployment_event)
      |> response(200)

      # Deployment must be reloaded from the db
      new_deployment = Ash.get!(Deployment, deployment.id, tenant: tenant)

      assert deployment.state == new_deployment.state
    end

    for event <- [:starting, :stopping, :error] do
      test "A new #{event} event gets created on interface publish", context do
        %{
          conn: conn,
          realm: realm,
          device: device,
          tenant: tenant,
          deployment: deployment
        } = context

        event_value = event_value(unquote(event), "test_event_message")
        timestamp = DateTime.to_iso8601(DateTime.utc_now())

        deployment_event = %{
          device_id: device.device_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
            path: "/" <> deployment.id,
            value: event_value
          },
          timestamp: timestamp
        }

        path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, deployment_event)
        |> response(200)

        assert [event] =
                 deployment
                 |> Ash.load!(:events)
                 |> Map.fetch!(:events)

        assert unquote(event) = event.type
        assert "test_event_message" = event.message
      end
    end

    for event <- [:starting, :stopping, :error] do
      test "A new #{event} event gets created on interface publish (event with add_info field)",
           context do
        %{
          conn: conn,
          realm: realm,
          device: device,
          tenant: tenant,
          deployment: deployment
        } = context

        event_value =
          event_value(unquote(event), "test_event_message", ["additional information about event"])

        timestamp = DateTime.to_iso8601(DateTime.utc_now())

        deployment_event = %{
          device_id: device.device_id,
          event: %{
            type: "incoming_data",
            interface: "io.edgehog.devicemanager.apps.DeploymentEvent",
            path: "/" <> deployment.id,
            value: event_value
          },
          timestamp: timestamp
        }

        path = Routes.astarte_trigger_path(conn, :process_event, tenant.slug)

        conn
        |> put_req_header("astarte-realm", realm.name)
        |> post(path, deployment_event)
        |> response(200)

        assert [event] =
                 deployment
                 |> Ash.load!(:events)
                 |> Map.fetch!(:events)

        assert unquote(event) = event.type
        assert "test_event_message" = event.message
        assert ["additional information about event"] = event.add_info
      end
    end
  end

  defp event_value(event, message), do: %{"status" => event |> to_string() |> String.capitalize(), "message" => message}

  defp event_value(event, message, add_info),
    do: %{"status" => event |> to_string() |> String.capitalize(), "message" => message, "addInfo" => add_info}
end
