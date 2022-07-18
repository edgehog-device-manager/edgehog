#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

  @version Mix.Project.config()[:version]

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting application version #{@version}.", tag: "edgehog_start")

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
      # Start the Endpoint (http/https)
      EdgehogWeb.Endpoint
      # Start a worker by calling: Edgehog.Worker.start_link(arg)
      # {Edgehog.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Edgehog.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EdgehogWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
