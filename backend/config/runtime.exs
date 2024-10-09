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

import Config

alias Waffle.Storage.Google.CloudStorage
alias Waffle.Storage.S3
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :edgehog, EdgehogWeb.Endpoint, server: true
end

# We need s3 storage configuration both in production and in integration tests
if config_env() in [:prod, :test] do
  # TODO: while you can use access key + secret key with S3-compatible storages,
  # Waffle's default S3 adapter doesn't work well with Google Cloud Storage.
  # To use GCP, you need to supply the JSON credentials of an authorized Service
  # Account instead, which are used by the GCP adapter for Waffle.
  s3 = %{
    access_key_id: System.get_env("S3_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("S3_SECRET_ACCESS_KEY"),
    gcp_credentials: System.get_env("S3_GCP_CREDENTIALS"),
    region: System.get_env("S3_REGION"),
    bucket: System.get_env("S3_BUCKET"),
    asset_host: System.get_env("S3_ASSET_HOST"),
    scheme: System.get_env("S3_SCHEME"),
    host: System.get_env("S3_HOST"),
    port: System.get_env("S3_PORT")
  }

  storage_module =
    cond do
      s3.host == "storage.googleapis.com" -> CloudStorage
      true -> S3
    end

  # The maximum upload size, particularly relevant for OTA updates. Default to 4 GB.
  max_upload_size_bytes =
    "MAX_UPLOAD_SIZE_BYTES"
    |> System.get_env(to_string(4_000_000_000))
    |> String.to_integer()

  %{
    waffle_bucket: waffle_bucket,
    waffle_asset_host: waffle_asset_host,
    waffle_virtual_host?: waffle_virtual_host?,
    edgehog_enable_s3_storage?: edgehog_enable_s3_storage?
  } =
        %{
          waffle_bucket: s3.bucket,
          waffle_asset_host: s3.asset_host,
          waffle_virtual_host?: true,
          edgehog_enable_s3_storage?: s3 |> Map.values() |> Enum.any?(&(!is_nil(&1)))
        }

  edgehog_enable_s3_storage? =
    case config_env() do
      :test -> true
      :prod -> edgehog_enable_s3_storage?
    end

  # Enable uploaders only when the S3 storage has been configured
  config :edgehog,
    enable_s3_storage?: edgehog_enable_s3_storage?,
    max_upload_size_bytes: max_upload_size_bytes

  config :ex_aws, :s3,
    scheme: s3.scheme,
    host: s3.host,
    port: s3.port

  config :ex_aws,
    region: s3.region,
    access_key_id: s3.access_key_id,
    secret_access_key: s3.secret_access_key

  config :goth,
    disabled: storage_module != CloudStorage,
    json: s3.gcp_credentials

  config :waffle,
    storage: storage_module,
    asset_host: waffle_asset_host,
    bucket: waffle_bucket,
    virtual_host: waffle_virtual_host?
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  database_username = System.fetch_env!("DATABASE_USERNAME")
  database_password = System.fetch_env!("DATABASE_PASSWORD")
  database_hostname = System.fetch_env!("DATABASE_HOSTNAME")
  database_name = System.fetch_env!("DATABASE_NAME")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # These are used to generate url links, they must consider reverse proxies
  url_host =
    System.get_env("URL_HOST") ||
      raise """
      environment variable URL_HOST is missing.
      It must point to the host where the Edgehog backend is exposed
      (also considering reverse proxies) since it's used to generate links.
      """

  # We're in the prod env, so assume https unless otherwise specified
  url_port = System.get_env("URL_PORT", "443")
  url_scheme = System.get_env("URL_SCHEME", "https")

  forwarder_secure_sessions? =
    System.get_env("EDGEHOG_FORWARDER_SECURE_SESSIONS", "true") == "true"

  forwarder_hostname = System.get_env("EDGEHOG_FORWARDER_HOSTNAME")

  config :edgehog, Edgehog.Repo,
    # ssl: true,
    # socket_options: [:inet6],
    username: database_username,
    password: database_password,
    hostname: database_hostname,
    database: database_name,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :edgehog, EdgehogWeb.Endpoint,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000"),
      protocol_options: [idle_timeout: 300_000]
    ],
    url: [
      host: url_host,
      scheme: url_scheme,
      port: url_port
    ],
    secret_key_base: secret_key_base

  if forwarder_hostname != nil &&
       (String.starts_with?(forwarder_hostname, "http://") ||
          String.starts_with?(forwarder_hostname, "https://")) do
    raise """
    environment variable EDGEHOG_FORWARDER_HOSTNAME must contain only the
    hostname without the http:// or https:// scheme.
    """
  end

  if url_host != nil &&
       (String.starts_with?(url_host, "http://") ||
          String.starts_with?(url_host, "https://")) do
    raise """
    environment variable URL_HOST must be a valid host, without the
    http:// or https:// scheme.
    """
  end

  forwarder_port = System.get_env("EDGEHOG_FORWARDER_PORT")

  forwarder_port =
    cond do
      forwarder_port != nil -> String.to_integer(forwarder_port)
      forwarder_secure_sessions? -> 443
      true -> 80
    end

  config :edgehog, :edgehog_forwarder, %{
    hostname: forwarder_hostname,
    port: forwarder_port,
    secure_sessions?: forwarder_secure_sessions?,
    enabled?: forwarder_hostname != nil
  }

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :edgehog, EdgehogWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :edgehog, Edgehog.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
