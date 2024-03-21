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
  pool_size: 50

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :edgehog, EdgehogWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "cJMfZ0TGL4Dy0e4kzSn5SrODWbgzWJ7E0rfWMKWvrtdiUjuYDrOQstMY/36V2ccd",
  server: false

# In test we don't send emails.
config :edgehog, Edgehog.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :tesla, adapter: Tesla.Mock

# Astarte mocks for tests
config :edgehog, :astarte_device_status_module, Edgehog.Astarte.Device.DeviceStatusMock
config :edgehog, :astarte_storage_usage_module, Edgehog.Astarte.Device.StorageUsageMock
config :edgehog, :astarte_wifi_scan_result_module, Edgehog.Astarte.Device.WiFiScanResultMock
config :edgehog, :astarte_system_status_module, Edgehog.Astarte.Device.SystemStatusMock
config :edgehog, :astarte_battery_status_module, Edgehog.Astarte.Device.BatteryStatusMock
config :edgehog, :astarte_base_image_module, Edgehog.Astarte.Device.BaseImageMock
config :edgehog, :astarte_hardware_info_module, Edgehog.Astarte.Device.HardwareInfoMock
config :edgehog, :astarte_os_info_module, Edgehog.Astarte.Device.OSInfoMock
config :edgehog, :astarte_ota_request_v0_module, Edgehog.Astarte.Device.OTARequestV0Mock
config :edgehog, :astarte_ota_request_v1_module, Edgehog.Astarte.Device.OTARequestV1Mock
config :edgehog, :astarte_runtime_info_module, Edgehog.Astarte.Device.RuntimeInfoMock
config :edgehog, :astarte_led_behavior_module, Edgehog.Astarte.Device.LedBehaviorMock
config :edgehog, :astarte_geolocation_module, Edgehog.Astarte.Device.GeolocationMock
config :edgehog, :astarte_network_interface_module, Edgehog.Astarte.Device.NetworkInterfaceMock
config :edgehog, :astarte_forwarder_session_module, Edgehog.Astarte.Device.ForwarderSessionMock

config :edgehog,
       :astarte_cellular_connection_module,
       Edgehog.Astarte.Device.CellularConnectionMock

config :edgehog, :astarte_interface_data_layer, Edgehog.Astarte.Interface.MockDataLayer
config :edgehog, :astarte_trigger_data_layer, Edgehog.Astarte.Trigger.MockDataLayer

# Reconciler mock for tests
config :edgehog, :reconciler_module, Edgehog.Tenants.ReconcilerMock

# Storage mocks for tests
config :edgehog, :assets_system_model_picture_module, Edgehog.Assets.SystemModelPictureMock
config :edgehog, :base_images_storage_module, Edgehog.BaseImages.StorageMock
config :edgehog, :os_management_ephemeral_image_module, Edgehog.OSManagement.EphemeralImageMock

# Enable s3 storage since we're using mocks for it
config :edgehog, enable_s3_storage?: true

# Geolocation mocks for tests
config :edgehog,
  preferred_geolocation_providers: [Edgehog.Geolocation.GeolocationProviderMock],
  preferred_geocoding_providers: [Edgehog.Geolocation.GeocodingProviderMock]

config :edgehog, ipbase_api_key: "test_api_key"

config :edgehog, google_geolocation_api_key: "test_api_key"

config :edgehog, google_geocoding_api_key: "test_api_key"

config :goth,
  disabled: true
