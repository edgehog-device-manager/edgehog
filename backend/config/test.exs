#
# This file is part of Edgehog.
#
# Copyright 2021 - 2026 SECO Mind Srl
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

import Config

config :edgehog, Oban, testing: :manual
config :ash, :disable_async?, true
config :ash, :missed_notifications, :ignore
config :ash, warn_on_transaction_hooks?: false

# In test we don't send emails.
config :edgehog, Edgehog.Mailer, adapter: Swoosh.Adapters.Test

# Disable PromEx metrics collection during tests
config :edgehog, Edgehog.PromEx, disabled: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :edgehog, Edgehog.Repo,
  username: "postgres",
  password: "postgres",
  database: "edgehog_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 50

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :edgehog, EdgehogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "cJMfZ0TGL4Dy0e4kzSn5SrODWbgzWJ7E0rfWMKWvrtdiUjuYDrOQstMY/36V2ccd",
  pubsub_server: Edgehog.PubSub,
  server: false

# Enable s3 storage since we're using mocks for it
config :edgehog, enable_s3_storage?: true

# Geolocation mocks for tests
config :edgehog, google_geocoding_api_key: "test_api_key"
config :edgehog, google_geolocation_api_key: "test_api_key"
config :edgehog, ipbase_api_key: "test_api_key"

config :edgehog,
  preferred_geolocation_providers: [Edgehog.Geolocation.Providers.TestGeolocation],
  preferred_geocoding_providers: [Edgehog.Geolocation.Providers.TestGeocoding]

config :goth,
  disabled: true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :tesla, adapter: Tesla.Mock

config :ash, :pub_sub, debug?: true
