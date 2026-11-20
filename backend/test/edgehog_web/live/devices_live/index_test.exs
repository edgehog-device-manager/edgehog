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

defmodule EdgehogWeb.DevicesLive.IndexTest do
  use EdgehogWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Edgehog.DevicesFixtures
  alias EdgehogWeb.Auth.Token

  defp generate_jwt(tenant_private_key, claims \\ nil) do
    jwk =
      tenant_private_key
      |> X509.PrivateKey.to_pem()
      |> JOSE.JWK.from_pem()

    now = DateTime.utc_now()

    base_claims = %{
      iss: "https://example.issuer.com/current",
      sub: Ash.UUIDv7.generate(),
      aud: "edgehog-test",
      exp: now |> DateTime.shift(hour: 2, day: 1) |> DateTime.to_unix(),
      iat: DateTime.to_unix(now),
      auth_time: now |> DateTime.shift(hour: 1) |> DateTime.to_unix(),
      preferred_username: "username",
      email: "example@email.com",
      given_name: "John",
      family_name: "Doe"
    }

    claims = Map.merge(base_claims, claims || %{e_tga: true})

    {:ok, jwt, _claims} =
      Token.encode_and_sign("dontcare", claims,
        secret: jwk,
        allowed_algos: ["ES256"]
      )

    jwt
  end

  describe "live-updating devices index and cell LiveComponents" do
    test "updates fleet stats and individual cell LiveComponents via granular PubSub topics",
         %{
           conn: conn,
           tenant: tenant,
           tenant_private_key: tenant_private_key
         } do
      jwt = generate_jwt(tenant_private_key)

      device1 =
        DevicesFixtures.device_fixture(
          tenant: tenant,
          name: "Gateway One",
          online: true,
          last_connection: ~U[2026-10-21 10:00:00Z]
        )

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      {:ok, devices_view, html} = live(recycle(conn), ~p"/tenants/#{tenant.slug}/devices")

      assert html =~ device1.name
      assert has_element?(devices_view, "#stat-total-devices", "1")
      assert has_element?(devices_view, "#stat-online-devices", "1")
      assert has_element?(devices_view, "#stat-offline-devices", "0")
      assert has_element?(devices_view, "#device-status-#{device1.id} [data-status='online']")
      assert has_element?(devices_view, "#device-name-#{device1.id}", "Gateway One")
      assert has_element?(devices_view, "#device-last-seen-#{device1.id}", "2026-10-21 10:00 UTC")

      # Provision a new online device while the LiveView is mounted
      device2 =
        DevicesFixtures.device_fixture(tenant: tenant, name: "Edge Sensor Two", online: true)

      _ = render(devices_view)
      updated_html = render_async(devices_view)
      assert updated_html =~ device2.name
      assert has_element?(devices_view, "#stat-total-devices", "2")
      assert has_element?(devices_view, "#stat-online-devices", "2")

      # 1. Transition device1 to offline via :from_device_status when last_connection is already set ->
      # updates StatusCellComponent, LastSeenCellComponent (selecting the newer last_disconnection),
      # and FleetStatsComponent
      Ash.update!(
        device1,
        %{online: false, last_disconnection: ~U[2026-10-21 15:30:00Z]},
        action: :from_device_status,
        tenant: tenant
      )

      _ = render(devices_view)
      assert has_element?(devices_view, "#device-status-#{device1.id} [data-status='offline']")
      assert has_element?(devices_view, "#device-last-seen-#{device1.id}", "2026-10-21 15:30 UTC")
      assert has_element?(devices_view, "#stat-online-devices", "1")
      assert has_element?(devices_view, "#stat-offline-devices", "1")

      # 2. Rename device1 via :update -> updates NameCellComponent via "devices:name:<id>"
      Ash.update!(device1, %{name: "Gateway One Renamed"},
        action: :update,
        tenant: tenant,
        authorize?: false
      )

      _ = render(devices_view)
      assert has_element?(devices_view, "#device-name-#{device1.id}", "Gateway One Renamed")

      # 3. Add tags to device1 via :add_tags -> updates TagsCellComponent via "devices:tags:<id>"
      Ash.update!(device1, %{tags: ["production", "eu-west"]},
        action: :add_tags,
        tenant: tenant,
        authorize?: false
      )

      _ = render(devices_view)
      assert has_element?(devices_view, "#device-tags-#{device1.id}", "production")
      assert has_element?(devices_view, "#device-tags-#{device1.id}", "eu-west")
    end
  end
end
