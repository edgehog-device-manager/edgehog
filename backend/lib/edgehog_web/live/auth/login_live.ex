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

defmodule EdgehogWeb.Auth.LoginLive do
  @moduledoc """
  LiveView for tenant-scoped authentication backed by Guardian (`EdgehogWeb.Auth`),
  URL query auto-login (`?tenantSlug=...&authToken=...`), customizable branding,
  and a reactive development quick-login LiveComponent.
  """
  use EdgehogWeb, :live_view

  import EdgehogWeb.Auth.FeatureShowcase, only: [feature_showcase: 1]

  alias Edgehog.Tenants.Tenant
  alias EdgehogWeb.Auth
  alias EdgehogWeb.Branding

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    dev_routes? = Application.get_env(:edgehog, :dev_routes, false)
    dev_tenants = if dev_routes?, do: load_dev_tenants(), else: []
    branding = Branding.current()

    {:ok,
     socket
     |> assign(:page_title, gettext("Sign in"))
     |> assign(:branding, branding)
     |> assign(:dev_routes?, dev_routes?)
     |> assign(:dev_tenants, dev_tenants)
     |> assign(:trigger_submit, false)
     |> assign(:redirect_to, nil)
     |> assign_login_form(%{})}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    %{tenant_slug: tenant_slug, auth_token: auth_token, redirect_to: redirect_to} =
      clean_login_params(params)

    cond do
      non_empty_binary?(tenant_slug) and non_empty_binary?(auth_token) ->
        query = build_auto_login_query(tenant_slug, auth_token, redirect_to)
        {:noreply, redirect(socket, to: "/session/auto?" <> query)}

      non_empty_binary?(tenant_slug) ->
        {:noreply,
         socket
         |> assign(:redirect_to, redirect_to)
         |> assign_login_form(%{"tenant_slug" => tenant_slug})}

      true ->
        {:noreply, assign(socket, :redirect_to, redirect_to)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"session" => session_params}, socket) do
    errors = validate_slug_format(session_params["tenant_slug"])
    form = to_form(session_params, as: :session, errors: errors)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("login", %{"session" => session_params}, socket) do
    clean_params =
      Map.reject(session_params, fn {k, _v} -> String.starts_with?(k, "_unused_") end)

    tenant_slug = Map.get(clean_params, "tenant_slug", "")
    auth_token = Map.get(clean_params, "auth_token", "")

    case Auth.authenticate_tenant(tenant_slug, auth_token) do
      {:ok, _tenant, _actor} ->
        {:noreply,
         socket
         |> assign(:form, to_form(clean_params, as: :session))
         |> assign(:trigger_submit, true)}

      {:error, field, message} ->
        form = to_form(clean_params, as: :session, errors: [{field, {message, []}}])
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:prefill_tenant_slug, slug}, socket) do
    {:noreply, assign_login_form(socket, %{"tenant_slug" => slug})}
  end

  defp assign_login_form(socket, params) do
    defaults = %{"tenant_slug" => "", "auth_token" => "", "keep_logged_in" => false}
    form = to_form(Map.merge(defaults, params), as: :session)

    assign(socket, :form, form)
  end

  defp clean_login_params(params) do
    %{
      tenant_slug: params["tenantSlug"] || params["tenant_slug"],
      auth_token: params["authToken"] || params["auth_token"],
      redirect_to: params["redirectTo"] || params["redirect_to"]
    }
  end

  defp non_empty_binary?(value), do: is_binary(value) and value != ""

  defp build_auto_login_query(tenant_slug, auth_token, redirect_to) do
    [
      {"tenantSlug", tenant_slug},
      {"authToken", auth_token},
      {"redirectTo", redirect_to}
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> URI.encode_query()
  end

  defp validate_slug_format(slug) when is_binary(slug) do
    trimmed = String.trim(slug)

    if trimmed != "" and not Regex.match?(~r/^[a-z0-9\-]+$/, trimmed) do
      [tenant_slug: {"must contain only lowercase letters, numbers, and hyphens", []}]
    else
      []
    end
  end

  defp validate_slug_format(_), do: []

  defp load_dev_tenants do
    case Ash.read(Tenant, authorize?: false) do
      {:ok, tenants} -> Enum.sort_by(tenants, & &1.slug)
      _ -> []
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col lg:flex-row bg-base-100 text-base-content">
      <div class="flex-1 flex flex-col justify-between px-6 py-8 sm:px-12 lg:px-16 xl:px-24">
        <div class="flex items-center justify-between gap-4">
          <div class="flex items-center gap-3">
            <img
              src={@branding.logo_url}
              alt={@branding.app_name}
              class="h-8 w-8 object-contain"
            />
            <span class="text-base font-bold tracking-tight text-base-content">
              {@branding.app_name}
            </span>
          </div>

          <.live_component
            module={EdgehogWeb.ThemeSelectorComponent}
            id="login-theme-selector"
          />
        </div>

        <div class="my-auto py-10 max-w-md w-full mx-auto lg:mx-0">
          <h1 class="text-2xl sm:text-3xl font-bold tracking-tight text-base-content">
            {gettext("Sign in to your tenant")}
          </h1>
          <p class="mt-2 text-sm text-base-content/65 leading-relaxed">
            {gettext(
              "Enter your tenant identifier and bearer token to access fleet telemetry, hardware inventory, and OTA campaigns."
            )}
          </p>

          <.form
            for={@form}
            id="login-form"
            action="/session"
            method="post"
            phx-change="validate"
            phx-submit="login"
            phx-trigger-action={@trigger_submit}
            class="mt-7 space-y-5"
          >
            <input :if={@redirect_to} type="hidden" name="session[redirect_to]" value={@redirect_to} />

            <.input
              field={@form[:tenant_slug]}
              type="text"
              label={gettext("Tenant Slug")}
              placeholder="acme-corp"
              autocomplete="organization"
              hint={gettext("Lowercase letters, numbers, and hyphens")}
              required
            />

            <.input
              field={@form[:auth_token]}
              type="textarea"
              rows="3"
              label={gettext("Authentication Token")}
              placeholder="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
              hint={gettext("Tenant-signed JWT with Edgehog claims")}
              required
            />

            <div class="flex items-center justify-between pt-1">
              <.input
                field={@form[:keep_logged_in]}
                type="checkbox"
                label={gettext("Keep session active on this workstation")}
              />
            </div>

            <div class="pt-1">
              <.button type="submit" class="w-full py-2.5">
                <span>{gettext("Connect to Tenant")}</span>
              </.button>
            </div>
          </.form>

          <.live_component
            :if={@dev_routes? and @dev_tenants != []}
            module={EdgehogWeb.Auth.DevQuickLoginComponent}
            id="dev-quick-login"
            tenants={@dev_tenants}
            redirect_to={@redirect_to}
          />
        </div>

        <div class="flex items-center justify-between text-xs text-base-content/50 pt-4 border-t border-base-300/70">
          <span>{@branding.app_name} · {@branding.subtitle}</span>
          <span class="font-mono">Phoenix LiveView + Ash</span>
        </div>
      </div>

      <.feature_showcase />
    </div>
    """
  end
end
