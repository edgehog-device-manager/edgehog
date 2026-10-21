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

defmodule EdgehogWeb.Branding do
  @moduledoc """
  Provides white-label branding configuration for Edgehog Web UI.

  Third-party customers can customize logos, application title, default theme
  mode (`"system" | "light" | "dark"`), and light/dark CSS custom property
  overrides via application configuration:

      config :edgehog, :branding,
        app_name: "Acme IoT Cloud",
        subtitle: "Industrial Fleet Console",
        logo_url: "/images/custom-logo.svg",
        logo_dark_url: "/images/custom-logo-dark.svg",
        default_theme: "system",
        light_vars: %{
          "--eh-brand-primary-light" => "oklch(47% 0.145 162)"
        },
        dark_vars: %{
          "--eh-brand-primary-dark" => "oklch(67% 0.15 160)"
        }
  """

  @default_branding %{
    app_name: "Edgehog",
    subtitle: "Device Manager",
    logo_url: "/images/logo.png",
    logo_dark_url: "/images/logo.png",
    brand_mark_url: "/images/brand.png",
    default_theme: "system",
    light_vars: %{},
    dark_vars: %{}
  }

  @doc """
  Returns the active branding map merged with any `:edgehog, :branding` overrides.
  """
  def current do
    configured =
      :edgehog
      |> Application.get_env(:branding, [])
      |> Map.new()

    Map.merge(@default_branding, configured)
  end

  @doc """
  Serializes configured `:light_vars` and `:dark_vars` into a `<style>` block
  body so third-party color overrides apply to `:root` in both light and dark modes.
  """
  def custom_css_vars do
    %{light_vars: light_vars, dark_vars: dark_vars} = current()

    light_block = format_css_rule(":root, :root[data-theme=\"light\"]", light_vars)
    dark_block = format_css_rule(":root[data-theme=\"dark\"]", dark_vars)

    [light_block, dark_block]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp format_css_rule(_selector, vars) when map_size(vars) == 0, do: ""

  defp format_css_rule(selector, vars) do
    declarations =
      Enum.map_join(vars, " ", fn {k, v} ->
        "#{k}: #{v};"
      end)

    "#{selector} { #{declarations} }"
  end
end
