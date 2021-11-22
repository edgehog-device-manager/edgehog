import Config

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
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :edgehog, EdgehogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "cJMfZ0TGL4Dy0e4kzSn5SrODWbgzWJ7E0rfWMKWvrtdiUjuYDrOQstMY/36V2ccd",
  server: false

# In test we don't send emails.
config :edgehog, Edgehog.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :tesla, adapter: Tesla.Mock

# Astarte mocks for tests
config :edgehog, :astarte_device_status_module, Edgehog.Astarte.Device.DeviceStatusMock
config :edgehog, :astarte_storage_usage_module, Edgehog.Astarte.Device.StorageUsageMock
config :edgehog, :astarte_wifi_scan_result_module, Edgehog.Astarte.Device.WiFiScanResultMock

config :edgehog,
  ip_geolocation_provider: Edgehog.Geolocation.IPGeolocationProviderMock,
  wifi_geolocation_provider: Edgehog.Geolocation.WiFiGeolocationProviderMock,
  geocoding_provider: Edgehog.Geolocation.GeocodingProviderMock

config :edgehog, Edgehog.Geolocation.Providers.FreeGeoIp, api_key: "test_api_key"

config :edgehog, Edgehog.Geolocation.Providers.GoogleGeolocation, api_key: "test_api_key"

config :edgehog, Edgehog.Geolocation.Providers.GoogleGeocoding, api_key: "test_api_key"
