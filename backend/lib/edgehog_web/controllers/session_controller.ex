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

defmodule EdgehogWeb.SessionController do
  use EdgehogWeb, :controller

  alias Edgehog.Tenants
  alias EdgehogWeb.Auth

  @doc """
  Redirects `/` to the active tenant's devices list if logged in, or `/login` otherwise.
  """
  def root(conn, _params) do
    tenant_slug = get_session(conn, "tenant_slug")
    auth_token = get_session(conn, "auth_token")

    case verify_active_session(conn, tenant_slug, auth_token) do
      {:ok, tenant} ->
        redirect(conn, to: "/tenants/#{tenant.slug}/devices")

      :error ->
        conn
        |> configure_session(drop: true)
        |> redirect(to: "/login")
    end
  end

  @doc """
  Creates a browser session after verifying the tenant slug and JWT auth token.
  """
  def create(conn, %{"session" => session_params}) do
    tenant_slug = Map.get(session_params, "tenant_slug", "")
    auth_token = Map.get(session_params, "auth_token", "")
    redirect_to = Map.get(session_params, "redirect_to")

    authenticate_and_establish_session(conn, tenant_slug, auth_token, redirect_to)
  end

  def create(conn, params) do
    tenant_slug = Map.get(params, "tenant_slug", "")
    auth_token = Map.get(params, "auth_token", "")
    redirect_to = Map.get(params, "redirect_to")

    authenticate_and_establish_session(conn, tenant_slug, auth_token, redirect_to)
  end

  @doc """
  Handles URL query parameter auto-login (`/session/auto?tenantSlug=...&authToken=...&redirectTo=...`),
  preserving parity with the React SPA's `AttemptLogin` route.
  """
  def auto(conn, params) do
    tenant_slug = Map.get(params, "tenantSlug") || Map.get(params, "tenant_slug", "")
    auth_token = Map.get(params, "authToken") || Map.get(params, "auth_token", "")
    redirect_to = Map.get(params, "redirectTo") || Map.get(params, "redirect_to")

    authenticate_and_establish_session(conn, tenant_slug, auth_token, redirect_to)
  end

  @doc """
  Development-only 1-click quick login for a tenant (`POST /session/dev`).
  Only active when `:dev_routes` is enabled.
  """
  def dev_create(conn, %{"tenant_slug" => tenant_slug} = params) do
    if Application.get_env(:edgehog, :dev_routes, false) do
      case tenant_slug |> String.trim() |> Tenants.fetch_tenant_by_slug() do
        {:ok, tenant} ->
          redirect_to = safe_redirect_path(params["redirect_to"], tenant.slug)

          conn
          |> configure_session(renew: true)
          |> put_session("tenant_slug", tenant.slug)
          |> put_session("auth_token", "dev_session")
          |> put_session("dev_bypass", true)
          |> put_flash(
            :info,
            gettext("Logged in to %{tenant} (Development mode).", tenant: tenant.name)
          )
          |> redirect(to: redirect_to)

        {:error, _} ->
          conn
          |> put_flash(:error, gettext("Selected tenant was not found."))
          |> redirect(to: "/login")
      end
    else
      conn
      |> put_status(:forbidden)
      |> text("Forbidden")
      |> halt()
    end
  end

  @doc """
  Clears the browser session and redirects to `/login`.
  """
  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/login")
  end

  defp authenticate_and_establish_session(conn, tenant_slug, auth_token, redirect_to) do
    case Auth.authenticate_tenant(tenant_slug, auth_token) do
      {:ok, tenant, _actor} ->
        destination = safe_redirect_path(redirect_to, tenant.slug)

        conn
        |> configure_session(renew: true)
        |> put_session("tenant_slug", tenant.slug)
        |> put_session("auth_token", String.trim(auth_token))
        |> delete_session("dev_bypass")
        |> redirect(to: destination)

      {:error, _field, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: "/login")
    end
  end

  defp safe_redirect_path(path, tenant_slug) when is_binary(path) do
    trimmed = String.trim(path)

    if String.starts_with?(trimmed, "/") and not String.starts_with?(trimmed, "//") do
      trimmed
    else
      "/tenants/#{tenant_slug}/devices"
    end
  end

  defp safe_redirect_path(_, tenant_slug), do: "/tenants/#{tenant_slug}/devices"

  defp verify_active_session(conn, tenant_slug, auth_token) when is_binary(tenant_slug) do
    dev_bypass? =
      get_session(conn, "dev_bypass") == true and
        Application.get_env(:edgehog, :dev_routes, false)

    cond do
      dev_bypass? ->
        case Tenants.fetch_tenant_by_slug(tenant_slug) do
          {:ok, tenant} -> {:ok, tenant}
          _ -> :error
        end

      is_binary(auth_token) ->
        case Auth.authenticate_tenant(tenant_slug, auth_token) do
          {:ok, tenant, _actor} -> {:ok, tenant}
          _ -> :error
        end

      true ->
        :error
    end
  end

  defp verify_active_session(_conn, _tenant_slug, _auth_token), do: :error
end
