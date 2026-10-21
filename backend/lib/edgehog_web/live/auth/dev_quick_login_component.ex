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

defmodule EdgehogWeb.Auth.DevQuickLoginComponent do
  @moduledoc """
  Reactive `Phoenix.LiveComponent` that renders development-only 1-click tenant
  session launchers and prefill controls on the login screen.
  """
  use EdgehogWeb, :live_component

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:filter, fn -> "" end)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("filter_tenants", %{"q" => query}, socket) do
    {:noreply, assign(socket, :filter, String.trim(query))}
  end

  def handle_event("prefill_slug", %{"slug" => slug}, socket) do
    send(self(), {:prefill_tenant_slug, slug})
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    filtered_tenants =
      Enum.filter(assigns.tenants, fn tenant ->
        q = String.downcase(assigns.filter)

        q == "" or
          String.contains?(String.downcase(tenant.name), q) or
          String.contains?(String.downcase(tenant.slug), q)
      end)

    assigns = assign(assigns, :filtered_tenants, filtered_tenants)

    ~H"""
    <section
      id={@id}
      class="card card-border bg-base-200/60 mt-6 p-4"
      aria-label={gettext("Development Quick Access")}
    >
      <div class="flex items-center justify-between gap-2 mb-3">
        <div class="flex items-center gap-2">
          <span class="status status-success" />
          <h2 class="text-xs font-semibold text-base-content">
            {gettext("Development Quick Access")}
          </h2>
        </div>
        <span class="badge badge-xs badge-ghost font-mono">
          dev_routes
        </span>
      </div>

      <p class="text-xs text-base-content/65 mb-3">
        {gettext("Launch a tenant session directly without signing a local JWT.")}
      </p>

      <form :if={length(@tenants) > 3} phx-change="filter_tenants" phx-target={@myself} class="mb-2.5">
        <input
          type="search"
          name="q"
          value={@filter}
          placeholder={gettext("Filter tenants...")}
          class="input input-xs w-full"
        />
      </form>

      <div :if={@filtered_tenants == []} class="py-2 text-xs text-base-content/55">
        {gettext("No matching development tenants found.")}
      </div>

      <div class="space-y-2">
        <div
          :for={tenant <- @filtered_tenants}
          class="card card-border bg-base-100 flex-row items-center justify-between gap-3 px-3 py-2"
        >
          <button
            type="button"
            phx-click="prefill_slug"
            phx-value-slug={tenant.slug}
            phx-target={@myself}
            class="text-left group cursor-pointer"
            title={gettext("Click to prefill tenant slug")}
          >
            <div class="text-xs font-semibold text-base-content group-hover:text-primary transition-colors">
              {tenant.name}
            </div>
            <div class="font-mono text-[11px] text-base-content/55">
              {tenant.slug}
            </div>
          </button>

          <form action="/session/dev" method="post">
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <input type="hidden" name="tenant_slug" value={tenant.slug} />
            <input :if={@redirect_to} type="hidden" name="redirect_to" value={@redirect_to} />
            <button type="submit" class="btn btn-xs btn-soft btn-primary gap-1.5">
              <span>{gettext("Open")}</span>
              <span class="font-mono">{tenant.slug}</span>
            </button>
          </form>
        </div>
      </div>
    </section>
    """
  end
end
