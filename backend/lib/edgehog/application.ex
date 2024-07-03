#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule Edgehog.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Edgehog.Config
  alias EdgehogWeb.Endpoint
  alias EdgehogWeb.Router

  require Logger

  @version Mix.Project.config()[:version]

  @impl Application
  def start(_type, _args) do
    Logger.info("Starting application version #{@version}.", tag: "edgehog_start")

    Config.validate_admin_authentication!()

    # We inject this here so that the non-web part of the application doesn't depend on the web part
    tenant_to_trigger_url_fun = fn %Edgehog.Tenants.Tenant{slug: slug} ->
      Router.Helpers.astarte_trigger_url(Endpoint, :process_event, slug)
    end

    children = [
      # Prometheus metrics
      Edgehog.PromEx,
      # Start the Ecto repository
      Edgehog.Repo,
      # Start the Telemetry supervisor
      EdgehogWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Edgehog.PubSub},
      # Start Finch
      {Finch, name: EdgehogFinch},
      # Start the UpdateCampaigns supervisor
      Edgehog.UpdateCampaigns.Supervisor,
      # Start the Tenant Reconciler Supervisor
      {Edgehog.Tenants.Reconciler.Supervisor, tenant_to_trigger_url_fun: tenant_to_trigger_url_fun},
      # Start the Endpoint (http/https)
      Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Edgehog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    EdgehogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
