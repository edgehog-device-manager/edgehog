#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule EdgehogWeb.AdminAPI do
  @moduledoc false

  use AshJsonApi.Router,
    domains: [Edgehog.Tenants],
    open_api: "/open_api"

  alias OpenApiSpex.Components
  alias OpenApiSpex.Info
  alias OpenApiSpex.OpenApi
  alias OpenApiSpex.SecurityScheme
  alias OpenApiSpex.Server

  @domains [Edgehog.Tenants]

  # Taken from ash_json_api/controllers/open_api.ex
  # TODO: this is needed to extract the YAML file by running
  # `mix openapi.spec.yaml --spec EdgehogWeb.AdminAPI`.
  # Ideally, AshJsonApi should support file generation out of the box.
  # See issue: https://github.com/ash-project/ash_json_api/issues/129
  def spec do
    %OpenApi{
      info: %Info{
        title: "Edgehog Admin API",
        version: "1"
      },
      servers: [
        Server.from_endpoint(EdgehogWeb.Endpoint)
      ],
      paths: AshJsonApi.OpenApi.paths(@domains),
      tags: AshJsonApi.OpenApi.tags(@domains),
      components: %Components{
        responses: AshJsonApi.OpenApi.responses(),
        schemas: AshJsonApi.OpenApi.schemas(@domains),
        securitySchemes: %{
          "api_key" => %SecurityScheme{
            type: "apiKey",
            description: "API Key provided in the Authorization header",
            name: "api_key",
            in: "header"
          }
        }
      },
      security: [
        %{
          # API Key security applies to all operations
          "api_key" => []
        }
      ]
    }
  end
end
