#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :edgehog,
  ecto_repos: [Edgehog.Repo]

# Configures the endpoint
config :edgehog, EdgehogWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: EdgehogWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Edgehog.PubSub,
  live_view: [signing_salt: "aiSLZVyY"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :edgehog, Edgehog.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:module, :function, :request_id, :tag, :tenant, :realm]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :tesla, :adapter, {Tesla.Adapter.Finch, name: EdgehogFinch, receive_timeout: 300_000}

config :ex_aws,
  json_codec: Jason

allowed_algos = [
  "ES256",
  "ES384",
  "ES512",
  "PS256",
  "PS384",
  "PS512",
  "RS256",
  "RS384",
  "RS512"
]

config :edgehog, EdgehogWeb.Auth.Token, allowed_algos: allowed_algos

config :edgehog, EdgehogWeb.AdminAPI.Auth.Token,
  allowed_algos: allowed_algos,
  secret_key: {Edgehog.Config, :admin_jwk!, []}

# Prometheus metrics
config :edgehog, Edgehog.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

config :edgehog, :edgehog_forwarder, %{
  hostname: "localhost",
  port: 4001,
  secure_sessions?: false,
  enabled?: true
}

config :edgehog, :ash_apis, [
  Edgehog.Astarte,
  Edgehog.Devices,
  Edgehog.Tenants
]

config :ash, :default_belongs_to_type, :integer
config :ash, :custom_types, id: Edgehog.Types.Id
config :ash, :utc_datetime_type, :datetime
config :ash_graphql, :default_managed_relationship_type_name_template, :action_name
config :ash_graphql, :allow_non_null_mutation_arguments?, true

resource_section_order = [
  :resource,
  :graphql,
  :json_api,
  :code_interface,
  :actions,
  :attributes,
  :relationships,
  :calculations,
  :aggregates,
  :identities,
  :validations,
  :preparations,
  :changes,
  :pub_sub,
  :multitenancy,
  :postgres
]

config :spark, :formatter,
  remove_parens?: true,
  "Ash.Resource": [
    section_order: resource_section_order
  ],
  "Edgehog.MultitenantResource": [
    type: Ash.Resource,
    section_order: resource_section_order
  ]

config :mime, :types, %{
  "application/vnd.api+json" => ["json"]
}

config :mime, :extensions, %{
  "json" => "application/vnd.api+json"
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
