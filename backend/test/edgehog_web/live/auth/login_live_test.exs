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

defmodule EdgehogWeb.Auth.LoginLiveTest do
  use EdgehogWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Edgehog.DevicesFixtures
  alias Edgehog.TenantsFixtures
  alias EdgehogWeb.Auth.Token
  alias EdgehogWeb.Branding

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

  describe "GET /login" do
    test "renders the login page with tenant slug, auth token, and theme selector component", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, ~p"/login")

      assert html =~ "Sign in to your tenant"
      assert has_element?(view, "#login-form")
      assert has_element?(view, "#session_tenant_slug")
      assert has_element?(view, "#session_auth_token")
      assert has_element?(view, "#login-theme-selector")
    end

    test "validates invalid tenant slug format on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html =
        view
        |> form("#login-form",
          session: %{"tenant_slug" => "INVALID_SLUG!", "auth_token" => "token"}
        )
        |> render_submit()

      assert html =~ "must contain only lowercase letters, numbers, and hyphens"
    end

    test "shows an error when submitting an unknown tenant slug", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html =
        view
        |> form("#login-form",
          session: %{"tenant_slug" => "non-existent-tenant", "auth_token" => "some-token"}
        )
        |> render_submit()

      assert html =~ "could not be found"
    end

    test "shows an error when submitting an invalid JWT auth token", %{conn: conn, tenant: tenant} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html =
        view
        |> form("#login-form",
          session: %{"tenant_slug" => tenant.slug, "auth_token" => "invalid-jwt-token"}
        )
        |> render_submit()

      assert html =~ "is invalid for this tenant"
    end

    test "triggers session POST and logs into tenant devices page when credentials are valid", %{
      conn: conn,
      tenant: tenant,
      tenant_private_key: tenant_private_key
    } do
      jwt = generate_jwt(tenant_private_key)
      device = DevicesFixtures.device_fixture(tenant: tenant, name: "Gateway Alpha", online: true)

      {:ok, view, _html} = live(conn, ~p"/login")

      form =
        form(view, "#login-form", session: %{"tenant_slug" => tenant.slug, "auth_token" => jwt})

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/tenants/#{tenant.slug}/devices"

      {:ok, devices_view, devices_html} = live(conn, ~p"/tenants/#{tenant.slug}/devices")
      assert devices_html =~ tenant.slug
      assert devices_html =~ device.name
      assert has_element?(devices_view, "#live-pubsub-indicator")
      assert has_element?(devices_view, "#fleet-stats")
      assert has_element?(devices_view, "#device-status-#{device.id}")
      assert has_element?(devices_view, "#device-name-#{device.id}")
    end

    test "supports auto-login via URL query parameters (?tenantSlug=...&authToken=...)", %{
      conn: conn,
      tenant: tenant,
      tenant_private_key: tenant_private_key
    } do
      jwt = generate_jwt(tenant_private_key)

      assert {:error, {:redirect, %{to: auto_url}}} =
               live(conn, ~p"/login?#{[tenantSlug: tenant.slug, authToken: jwt]}")

      conn = get(conn, auto_url)
      assert redirected_to(conn) == ~p"/tenants/#{tenant.slug}/devices"
    end
  end

  describe "theming and white-label branding" do
    test "ThemeSelectorComponent switches light, dark, and system modes live", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      refute has_element?(view, "[data-brand-preset-option]")

      view
      |> element("#login-theme-selector button[data-theme-option='dark']")
      |> render_click()

      assert has_element?(
               view,
               "#login-theme-selector button[data-theme-option='dark'].bg-base-100"
             )

      view
      |> element("#login-theme-selector button[data-theme-option='light']")
      |> render_click()

      assert has_element?(
               view,
               "#login-theme-selector button[data-theme-option='light'].bg-base-100"
             )

      view
      |> element("#login-theme-selector button[data-theme-option='system']")
      |> render_click()

      assert has_element?(
               view,
               "#login-theme-selector button[data-theme-option='system'].bg-base-100"
             )
    end

    test "EdgehogWeb.Branding applies custom white-label app name, logo, and CSS color variables",
         %{conn: conn} do
      prev = Application.get_env(:edgehog, :branding)

      Application.put_env(:edgehog, :branding,
        app_name: "Acme Industrial Cloud",
        subtitle: "Fleet Operations",
        logo_url: "/images/custom-logo.png",
        light_vars: %{"--eh-brand-primary-light" => "oklch(47% 0.145 162)"},
        dark_vars: %{"--eh-brand-primary-dark" => "oklch(67% 0.15 160)"}
      )

      on_exit(fn ->
        if prev,
          do: Application.put_env(:edgehog, :branding, prev),
          else: Application.delete_env(:edgehog, :branding)
      end)

      assert Branding.current().app_name == "Acme Industrial Cloud"
      assert Branding.custom_css_vars() =~ "--eh-brand-primary-light: oklch(47% 0.145 162);"
      assert Branding.custom_css_vars() =~ "--eh-brand-primary-dark: oklch(67% 0.15 160);"

      {:ok, _view, html} = live(conn, ~p"/login")
      assert html =~ "Acme Industrial Cloud"
      assert html =~ "/images/custom-logo.png"
    end
  end

  describe "protected routes, session isolation, DevQuickLoginComponent, and logout" do
    test "redirects unauthenticated users from /tenants/:tenant_slug/devices to /login", %{
      conn: conn,
      tenant: tenant
    } do
      assert {:error, {:redirect, %{to: "/login"}}} =
               live(conn, ~p"/tenants/#{tenant.slug}/devices")
    end

    test "rejects cross-tenant navigation and redirects to /login?tenant_slug=<other>", %{
      conn: conn,
      tenant: tenant_a,
      tenant_private_key: tenant_a_private_key
    } do
      tenant_b = TenantsFixtures.tenant_fixture()
      jwt_a = generate_jwt(tenant_a_private_key)

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant_a.slug, "auth_token" => jwt_a}
        })

      assert redirected_to(conn) == ~p"/tenants/#{tenant_a.slug}/devices"

      expected_login_url = "/login?tenant_slug=#{tenant_b.slug}"

      assert {:error, {:redirect, %{to: ^expected_login_url}}} =
               live(recycle(conn), ~p"/tenants/#{tenant_b.slug}/devices")
    end

    test "GET / with a stale tenant_slug and invalid auth_token clears session and redirects to /login",
         %{
           conn: conn,
           tenant: tenant
         } do
      conn =
        conn
        |> init_test_session(%{
          "tenant_slug" => tenant.slug,
          "auth_token" => "expired-or-invalid-jwt"
        })
        |> get(~p"/")

      assert redirected_to(conn) == ~p"/login"
      assert conn.private.plug_session_info == :drop
    end

    test "DELETE /session clears session and redirects to /login", %{
      conn: conn,
      tenant: tenant,
      tenant_private_key: tenant_private_key
    } do
      jwt = generate_jwt(tenant_private_key)

      conn =
        post(conn, ~p"/session", %{
          "session" => %{"tenant_slug" => tenant.slug, "auth_token" => jwt}
        })

      assert redirected_to(conn) == ~p"/tenants/#{tenant.slug}/devices"

      conn = delete(recycle(conn), ~p"/session")
      assert redirected_to(conn) == ~p"/login"

      assert {:error, {:redirect, %{to: "/login"}}} =
               live(recycle(conn), ~p"/tenants/#{tenant.slug}/devices")
    end

    test "DevQuickLoginComponent renders in dev mode and POST /session/dev logs in directly", %{
      conn: conn,
      tenant: tenant
    } do
      prev = Application.get_env(:edgehog, :dev_routes, false)
      Application.put_env(:edgehog, :dev_routes, true)
      on_exit(fn -> Application.put_env(:edgehog, :dev_routes, prev) end)

      {:ok, view, html} = live(conn, ~p"/login")
      assert html =~ "Development Quick Access"
      assert has_element?(view, "#dev-quick-login")

      conn = post(conn, ~p"/session/dev", %{"tenant_slug" => tenant.slug})
      assert redirected_to(conn) == ~p"/tenants/#{tenant.slug}/devices"

      {:ok, _devices_view, devices_html} = live(conn, ~p"/tenants/#{tenant.slug}/devices")
      assert devices_html =~ tenant.name
    end
  end
end
