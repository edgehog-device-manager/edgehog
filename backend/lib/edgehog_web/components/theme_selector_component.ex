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

defmodule EdgehogWeb.ThemeSelectorComponent do
  @moduledoc """
  Reactive `Phoenix.LiveComponent` for switching light, dark, and system theme
  variants live without page reloads.
  """
  use EdgehogWeb, :live_component

  alias EdgehogWeb.Branding
  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveComponent
  def mount(socket) do
    branding = Branding.current()

    {:ok, assign(socket, :theme_mode, branding.default_theme)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("set_theme", %{"theme" => theme}, socket)
      when theme in ["system", "light", "dark"] do
    {:noreply, assign(socket, :theme_mode, theme)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex items-center" data-theme-selector>
      <div
        class="join border border-base-300 bg-base-200/70 p-0.5 rounded-field"
        role="group"
        aria-label={gettext("Color theme")}
      >
        <button
          type="button"
          data-theme-option="system"
          phx-click={
            JS.dispatch("phx:set-theme", detail: %{theme: "system"})
            |> JS.push("set_theme", value: %{theme: "system"}, target: @myself)
          }
          class={[
            "join-item btn btn-xs gap-1 border-0",
            if(@theme_mode == "system",
              do: "btn-active bg-base-100 text-base-content shadow-2xs",
              else: "btn-ghost text-base-content/65"
            )
          ]}
          title={gettext("System theme")}
        >
          <.icon name="hero-computer-desktop-micro" class="size-3.5" />
          <span class="hidden sm:inline">{gettext("Auto")}</span>
        </button>

        <button
          type="button"
          data-theme-option="light"
          phx-click={
            JS.dispatch("phx:set-theme", detail: %{theme: "light"})
            |> JS.push("set_theme", value: %{theme: "light"}, target: @myself)
          }
          class={[
            "join-item btn btn-xs gap-1 border-0",
            if(@theme_mode == "light",
              do: "btn-active bg-base-100 text-base-content shadow-2xs",
              else: "btn-ghost text-base-content/65"
            )
          ]}
          title={gettext("Light theme")}
        >
          <.icon name="hero-sun-micro" class="size-3.5" />
          <span class="hidden sm:inline">{gettext("Light")}</span>
        </button>

        <button
          type="button"
          data-theme-option="dark"
          phx-click={
            JS.dispatch("phx:set-theme", detail: %{theme: "dark"})
            |> JS.push("set_theme", value: %{theme: "dark"}, target: @myself)
          }
          class={[
            "join-item btn btn-xs gap-1 border-0",
            if(@theme_mode == "dark",
              do: "btn-active bg-base-100 text-base-content shadow-2xs",
              else: "btn-ghost text-base-content/65"
            )
          ]}
          title={gettext("Dark theme")}
        >
          <.icon name="hero-moon-micro" class="size-3.5" />
          <span class="hidden sm:inline">{gettext("Dark")}</span>
        </button>
      </div>
    </div>
    """
  end
end
