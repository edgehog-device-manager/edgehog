#
# This file is part of Edgehog.
#
# Copyright 2021-2022 SECO Mind Srl
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

defmodule Edgehog.MixProject do
  use Mix.Project

  def project do
    [
      app: :edgehog,
      version: "0.5.2",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_core_path: dialyzer_cache_directory(Mix.env())
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Edgehog.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.2"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.3"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:absinthe, "~> 1.6"},
      {:absinthe_plug, "~> 1.5"},
      {:absinthe_relay, "~> 1.5"},
      {:dataloader, "~> 1.0"},
      # TODO: remove when tesla makes a new release compatible with mime ~> 2.0
      {:mime, "~> 2.0", override: true},
      {:astarte_client, github: "astarte-platform/astarte-client-elixir"},
      {:cors_plug, "~> 2.0"},
      {:x509, "~> 0.8"},
      {:mox, "~> 1.0"},
      {:tesla, "~> 1.4"},
      {:finch, "~> 0.12", override: true},
      {:waffle, "~> 1.1"},
      {:ex_aws, "~> 2.2"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.6"},
      {:waffle_gcs, "~> 0.2"},
      {:guardian, "~> 2.0"},
      {:jose, "~> 1.8"},
      {:skogsra, "~> 2.3"},
      {:excoveralls, "~> 0.10", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :ci], runtime: false},
      {:pretty_log, "~> 0.1"},
      {:prom_ex, "~> 1.7.1"},
      {:plug_heartbeat, "~> 1.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp dialyzer_cache_directory(:ci) do
    "priv/plts"
  end

  defp dialyzer_cache_directory(_) do
    nil
  end
end
