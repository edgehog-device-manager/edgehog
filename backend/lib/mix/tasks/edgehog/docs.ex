#
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
#

defmodule Mix.Tasks.Edgehog.Docs do
  @shortdoc "Generate Edgehog documentation including interfaces, tenant API, and admin API docs"

  @moduledoc """
  A Mix task for generating the full Edgehog documentation suite.

  This task orchestrates the generation of three distinct documentation outputs:

  - **Interfaces docs** – Markdown documentation generated from Astarte interface definitions
    using the `astarte-docs` CLI tool.
  - **Tenant GraphQL API docs** – HTML documentation generated from the Absinthe GraphQL
    schema using `spectaql`.
  - **Admin REST API docs** – OpenAPI spec and a SwaggerUI-based HTML viewer, generated
    by cloning the SwaggerUI repository and running `openapi.spec.yaml`.

  ## Usage

      mix edgehog.docs [options]

  ## Options

    * `--interfaces` / `--no-interfaces` – Include or skip interface documentation (default: `true`)
    * `--admin-api` / `--no-admin-api` – Include or skip admin REST API docs (default: `true`)
    * `--tenant-api` / `--no-tenant-api` – Include or skip tenant GraphQL API docs (default: `true`)
    * `--output` – Output directory for generated documentation
    * `--interfaces-path` – Path to the directory containing Astarte interface definitions

  ## Prerequisites

  The task checks that all required external programs are available in `$PATH` before running:

    * `astarte-docs` – required for interface documentation
    * `npx` – required for tenant API documentation
    * `git` – required for admin API documentation
  """

  use Mix.Task

  require Logger

  @args [
    interfaces: :boolean,
    admin_api: :boolean,
    tenant_api: :boolean,
    output: :string,
    interfaces_path: :string
  ]
  @swagger_repo "https://github.com/swagger-api/swagger-ui.git"
  @swagger_version "v5.30.2"
  @project_root String.replace(Mix.Project.project_file(), "/mix.exs", "")
  @preferred_cli_env :dev

  @impl Mix.Task
  def run(argv) do
    {opts, _} = OptionParser.parse!(argv, strict: @args)

    missing_programs =
      opts
      |> check_required_programs()
      |> Enum.reject(&match?(:ok, &1))

    required_programs_available? = Enum.empty?(missing_programs)

    if required_programs_available?,
      do: docs_pipeline(opts),
      else: log_missing(missing_programs)
  end

  defp docs_pipeline(opts) do
    if Keyword.get(opts, :interfaces, true),
      do: build_interfaces_docs(Keyword.get(opts, :interfaces_path))

    Mix.Task.run("docs")

    if Keyword.get(opts, :tenant_api, true),
      do: build_tenant_api_docs()

    if Keyword.get(opts, :admin_api, true),
      do: build_admin_api_docs()
  end

  defp build_interfaces_docs(interfaces_path) do
    dest = "#{@project_root}/docs/pages/integrating/astarte_interfaces.md"

    command = ~s<astarte-docs interfaces gen-markdown -d "#{interfaces_path}" -o #{dest}>

    run_shell_command(command)
  end

  defp log_missing(missing) do
    for {:missing, program, pipeline} <- missing do
      Logger.error("#{program} not found in $PATH", pipeline: pipeline)
    end

    :ok
  end

  defp check_required_programs(opts) do
    required_programs = []

    required_programs =
      if Keyword.get(opts, :interfaces, true),
        do: [{"astarte-docs", :interfaces} | required_programs],
        else: required_programs

    required_programs =
      if Keyword.get(opts, :tenant_api, true),
        do: [{"npx", :tenant_api} | required_programs],
        else: required_programs

    required_programs =
      if Keyword.get(opts, :admin_api, true),
        do: [{"git", :admin_api} | required_programs],
        else: required_programs

    Enum.map(required_programs, &find_program/1)
  end

  defp build_tenant_api_docs do
    Mix.Task.run("absinthe.schema.sdl", ["--schema", "EdgehogWeb.Schema"])

    tenant_api_path = "#{doc_path()}/tenant-graphql-api"
    File.mkdir(tenant_api_path)

    command = ~s<npx spectaql .spectaql-config.yaml -t "#{tenant_api_path}">

    case run_shell_command(command) do
      :ok ->
        File.rm("schema.graphql")

      {:error, code} ->
        Logger.warning("Error while running #{command} (unixcode #{code}), possible `schema.graphql` file left behind.")
    end
  end

  defp build_admin_api_docs do
    Logger.info("Resetting database")
    Mix.Task.run("ash.reset")

    admin_rest_api_path = "#{doc_path()}/admin-rest-api"

    File.mkdir(admin_rest_api_path)

    # Put SwaggerUI dist in `admin_rest_api_path`
    now = to_string(System.os_time())
    swagger_dir = "/tmp/swagger-ui-#{now}"
    command = "git clone #{@swagger_repo} #{swagger_dir} -b #{@swagger_version}"

    Logger.info("Cloning swagger-ui under #{swagger_dir}")
    run_shell_command(command)

    Logger.info("Copying swagger-ui under #{admin_rest_api_path}")
    File.cp_r("#{swagger_dir}/dist", "#{admin_rest_api_path}")

    # Generate OpenAPI spec in the correct path
    argv = [
      "--spec",
      "EdgehogWeb.AdminAPI",
      "--filename",
      "#{admin_rest_api_path}/openapi.yaml"
    ]

    Logger.info("Generating OpenAPI spec for the project")
    Mix.Task.run("openapi.spec.yaml", argv)

    # Copy our edited index
    File.cp!("#{@project_root}/docs/swagger-ui-index.html", "#{admin_rest_api_path}/index.html")
  end

  @spec run_shell_command(command :: String.t()) :: :ok | {:error, non_neg_integer()}
  defp run_shell_command(command) do
    {_out, unixcode} = System.shell(command)

    case unixcode do
      0 -> :ok
      code -> {:error, code}
    end
  end

  @spec find_program({String.t(), atom()}) :: :ok | {:error, term()}
  defp find_program({program, pipeline}) do
    case System.find_executable(program) do
      nil -> {:missing, program, pipeline}
      _path -> :ok
    end
  end

  defp doc_path, do: "#{@project_root}/doc"
end
