import Config

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

  config :edgehog, Edgehog.Repo,
    # ssl: true,
    # socket_options: [:inet6],
    username: database_username,
    password: database_password,
    hostname: database_hostname,
    database: database_name,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

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

  config :edgehog, EdgehogWeb.Endpoint,
    server: true,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base

  freegeoip_api_key = System.get_env("FREEGEOIP_API_KEY")

  freegeoip_provider = %{
    module: Edgehog.Geolocation.Providers.FreeGeoIp,
    enabled?: !is_nil(freegeoip_api_key),
    config: [api_key: freegeoip_api_key]
  }

  google_geolocation_api_key = System.get_env("GOOGLE_GEOLOCATION_API_KEY")

  google_geolocation_provider = %{
    module: Edgehog.Geolocation.Providers.GoogleGeolocation,
    enabled?: !is_nil(google_geolocation_api_key),
    config: [api_key: google_geolocation_api_key]
  }

  google_geocoding_api_key = System.get_env("GOOGLE_GEOCODING_API_KEY")

  google_geocoding_provider = %{
    module: Edgehog.Geolocation.Providers.GoogleGeocoding,
    enabled?: !is_nil(google_geocoding_api_key),
    config: [api_key: google_geocoding_api_key]
  }

  geolocation_providers = [google_geolocation_provider, freegeoip_provider]
  geocoding_providers = [google_geocoding_provider]

  config :edgehog,
    geolocation_providers:
      geolocation_providers |> Enum.filter(& &1.enabled?) |> Enum.map(& &1.module),
    geocoding_providers:
      geocoding_providers |> Enum.filter(& &1.enabled?) |> Enum.map(& &1.module)

  Enum.each(geolocation_providers ++ geocoding_providers, fn provider ->
    config :edgehog, provider.module, provider.config
  end)

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

  # Enable uploaders only when the S3 storage has been configured
  config :edgehog,
    enable_s3_storage?: Enum.any?(s3, fn {_, v} -> v != nil end)

  use_google_cloud_storage =
    case s3.host do
      "storage.googleapis.com" -> true
      _ -> false
    end

  s3_storage_module =
    if use_google_cloud_storage do
      Waffle.Storage.Google.CloudStorage
    else
      Waffle.Storage.S3
    end

  disable_authentication = System.get_env("DISABLE_AUTHENTICATION") || false
  config :edgehog, :disable_authentication, disable_authentication

  config :waffle,
    storage: s3_storage_module,
    bucket: s3.bucket,
    asset_host: s3.asset_host,
    virtual_host: true

  config :ex_aws,
    region: s3.region,
    access_key_id: s3.access_key_id,
    secret_access_key: s3.secret_access_key

  config :ex_aws, :s3,
    scheme: s3.scheme,
    host: s3.host,
    port: s3.port

  config :goth,
    disabled: !use_google_cloud_storage,
    json: s3.gcp_credentials

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
