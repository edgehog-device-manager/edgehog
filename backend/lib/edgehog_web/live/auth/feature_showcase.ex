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

defmodule EdgehogWeb.Auth.FeatureShowcase do
  @moduledoc """
  Static functional component displaying Edgehog platform capabilities
  (fleet management, OTA campaigns, containers, and file transfer) on the login screen.
  """
  use EdgehogWeb, :html

  @doc """
  Renders the Edgehog platform capabilities aside panel on the login page.
  """
  def feature_showcase(assigns) do
    assigns = assign(assigns, :features, features())

    ~H"""
    <aside
      class="hidden lg:flex lg:w-[46%] xl:w-[48%] flex-col justify-between bg-base-200 border-l border-base-300 p-12 xl:p-16"
      aria-label={gettext("Platform capabilities")}
    >
      <div class="flex items-center justify-between">
        <div class="badge badge-lg border-base-300 bg-base-100 gap-2 text-xs font-medium text-base-content/80">
          <span class="status status-success" />
          <span>{gettext("Real-time Astarte + Ash PubSub Telemetry")}</span>
        </div>
        <span class="font-mono text-xs text-base-content/55">TLS 1.3 / JWT</span>
      </div>

      <div class="my-auto py-8">
        <div class="card card-border bg-base-100 p-6 shadow-xs">
          <div class="flex items-center justify-between pb-4 mb-5 border-b border-base-300">
            <div>
              <h2 class="text-sm font-semibold text-base-content">
                {gettext("Edge Fleet & Lifecycle Management")}
              </h2>
              <p class="text-xs text-base-content/60 mt-0.5">
                {gettext("Multi-tenant device state synchronized over Phoenix Channels")}
              </p>
            </div>
            <span class="badge badge-soft badge-primary badge-sm font-mono font-semibold">
              LIVE
            </span>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
            <div
              :for={feature <- @features}
              class="card card-border bg-base-200/40 p-4 justify-between"
            >
              <div>
                <div class="flex items-center justify-between gap-2 mb-2.5">
                  <span class="inline-flex items-center justify-center size-8 rounded-md bg-primary/10 text-primary">
                    <.icon name={feature.icon} class="size-4" />
                  </span>
                  <span class="font-mono text-[11px] text-base-content/50">
                    {feature.tag}
                  </span>
                </div>
                <h3 class="text-xs font-semibold text-base-content">
                  {feature.title}
                </h3>
                <p class="mt-1 text-xs text-base-content/65 leading-relaxed">
                  {feature.description}
                </p>
              </div>
            </div>
          </div>

          <dl class="mt-5 grid grid-cols-3 gap-3 pt-4 border-t border-base-300">
            <div>
              <dt class="text-xs text-base-content/60">{gettext("Isolation")}</dt>
              <dd class="mt-0.5 font-mono text-xs font-semibold text-base-content">
                Per-Tenant JWT
              </dd>
            </div>
            <div>
              <dt class="text-xs text-base-content/60">{gettext("Updates")}</dt>
              <dd class="mt-0.5 font-mono text-xs font-semibold text-base-content">
                Ash.Notifier
              </dd>
            </div>
            <div>
              <dt class="text-xs text-base-content/60">{gettext("Branding")}</dt>
              <dd class="mt-0.5 font-mono text-xs font-semibold text-base-content">
                White-Label
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <p class="text-xs text-base-content/55 leading-relaxed">
        {gettext(
          "Supports URL token handoff (?tenantSlug=...&authToken=...) for seamless integration with external identity portals."
        )}
      </p>
    </aside>
    """
  end

  defp features do
    [
      %{
        icon: "hero-cpu-chip",
        tag: "Edgehog.Devices",
        title: gettext("Fleet Management"),
        description:
          gettext(
            "Monitor live connection state, hardware inventory, system models, and dynamic device groups."
          )
      },
      %{
        icon: "hero-arrow-path",
        tag: "Edgehog.Campaigns",
        title: gettext("OTA Updates"),
        description:
          gettext(
            "Orchestrate base image collections and staged OS rollout campaigns with automatic rollback."
          )
      },
      %{
        icon: "hero-cube",
        tag: "Edgehog.Containers",
        title: gettext("Containers"),
        description:
          gettext(
            "Deploy and manage multi-container workloads, images, networks, and volumes at the edge."
          )
      },
      %{
        icon: "hero-folder-arrow-down",
        tag: "Edgehog.Files",
        title: gettext("Files & Forwarder"),
        description:
          gettext(
            "Distribute artifacts via managed repositories and open secure remote device sessions."
          )
      }
    ]
  end
end
