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

defmodule EdgehogWeb.LiveAuth do
  @moduledoc """
  LiveView `on_mount` hooks for authenticating tenant sessions and scoping Ash operations.
  """

  import Phoenix.Component
  import Phoenix.LiveView

  alias Edgehog.Actors.Actor
  alias Edgehog.Tenants
  alias EdgehogWeb.Auth

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    case resolve_session(session) do
      {:ok, tenant, _actor} ->
        {:halt, redirect(socket, to: "/tenants/#{tenant.slug}/devices")}

      :error ->
        {:cont, assign(socket, current_tenant: nil, current_actor: nil)}
    end
  end

  def on_mount(:require_authenticated, params, session, socket) do
    case resolve_session(session) do
      {:ok, tenant, actor} ->
        requested_slug = params["tenant_slug"]

        if is_nil(requested_slug) or requested_slug == tenant.slug do
          {:cont,
           socket
           |> assign(:current_tenant, tenant)
           |> assign(:current_actor, actor)}
        else
          {:halt,
           socket
           |> put_flash(
             :error,
             "Your active session belongs to tenant '#{tenant.slug}'. Please log in to '#{requested_slug}' to access it."
           )
           |> redirect(to: "/login?tenant_slug=#{requested_slug}")}
        end

      :error ->
        {:halt, redirect(socket, to: "/login")}
    end
  end

  defp resolve_session(session) do
    tenant_slug = session["tenant_slug"]
    auth_token = session["auth_token"]

    if dev_bypass_session?(session) do
      verify_dev_session(tenant_slug)
    else
      verify_token_session(tenant_slug, auth_token)
    end
  end

  defp dev_bypass_session?(session) do
    session["dev_bypass"] == true and Application.get_env(:edgehog, :dev_routes, false)
  end

  defp verify_dev_session(tenant_slug) when is_binary(tenant_slug) do
    case Tenants.fetch_tenant_by_slug(tenant_slug) do
      {:ok, tenant} -> {:ok, tenant, %Actor{claims: %{"e_tga" => true}}}
      _ -> :error
    end
  end

  defp verify_dev_session(_tenant_slug), do: :error

  defp verify_token_session(tenant_slug, auth_token)
       when is_binary(tenant_slug) and is_binary(auth_token) do
    case Auth.authenticate_tenant(tenant_slug, auth_token) do
      {:ok, tenant, actor} -> {:ok, tenant, actor}
      _ -> :error
    end
  end

  defp verify_token_session(_tenant_slug, _auth_token), do: :error
end
