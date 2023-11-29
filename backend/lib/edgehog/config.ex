#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule Edgehog.Config do
  @moduledoc """
  This module handles the configuration of Edgehog
  """
  use Skogsra
  alias Edgehog.Config.{GeocodingProviders, GeolocationProviders, JWTPublicKeyPEMType}
  alias Edgehog.Geolocation

  @envdoc """
  Disables admin authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_admin_authentication, :edgehog, :disable_admin_authentication,
    os_env: "DISABLE_ADMIN_AUTHENTICATION",
    type: :boolean,
    default: false

  @envdoc "The Admin API JWT public key."
  app_env :admin_jwk, :edgehog, :admin_jwk,
    os_env: "ADMIN_JWT_PUBLIC_KEY_PATH",
    type: JWTPublicKeyPEMType

  @envdoc """
  Disables tenant authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_tenant_authentication, :edgehog, :disable_tenant_authentication,
    os_env: "DISABLE_TENANT_AUTHENTICATION",
    type: :boolean,
    default: false

  @envdoc "The API key for the ipbase.com geolocation provider."
  app_env :ipbase_api_key, :edgehog, :ipbase_api_key,
    os_env: "IPBASE_API_KEY",
    type: :binary

  @envdoc "The API key for the Google geolocation provider."
  app_env :google_geolocation_api_key, :edgehog, :google_geolocation_api_key,
    os_env: "GOOGLE_GEOLOCATION_API_KEY",
    type: :binary

  @envdoc "The API key for the Google geocoding provider."
  app_env :google_geocoding_api_key, :edgehog, :google_geocoding_api_key,
    os_env: "GOOGLE_GEOCODING_API_KEY",
    type: :binary

  @envdoc """
  A comma separated list of preferred geolocation providers.
  Possible values are: device, google, ipbase.
  """
  app_env :preferred_geolocation_providers, :edgehog, :preferred_geolocation_providers,
    os_env: "PREFERRED_GEOLOCATION_PROVIDERS",
    type: GeolocationProviders,
    default: [
      Geolocation.Providers.DeviceGeolocation,
      Geolocation.Providers.GoogleGeolocation,
      Geolocation.Providers.IPBase
    ]

  @envdoc """
  A comma separated list of preferred geocoding providers.
  Possible values are: google
  """
  app_env :preferred_geocoding_providers, :edgehog, :preferred_geocoding_providers,
    os_env: "PREFERRED_GEOCODING_PROVIDERS",
    type: GeocodingProviders,
    default: [Geolocation.Providers.GoogleGeocoding]

  @doc """
  Returns true if admin authentication is disabled.
  """
  @spec admin_authentication_disabled?() :: boolean()
  def admin_authentication_disabled?, do: disable_admin_authentication!()

  @doc """
  Returns true if tenant authentication is disabled.
  """
  @spec tenant_authentication_disabled?() :: boolean()
  def tenant_authentication_disabled?, do: disable_tenant_authentication!()

  @doc """
  Returns the list of geolocation modules to use.
  """
  @spec geolocation_providers!() :: list(atom())
  def geolocation_providers! do
    disabled_providers = %{
      Edgehog.Geolocation.Providers.IPBase => is_nil(ipbase_api_key!()),
      Edgehog.Geolocation.Providers.GoogleGeolocation => is_nil(google_geolocation_api_key!())
    }

    preferred_geolocation_providers!() |> Enum.reject(&disabled_providers[&1])
  end

  @doc """
  Returns the list of geocoding modules to use.
  """
  @spec geocoding_providers!() :: list(atom())
  def geocoding_providers! do
    disabled_providers = %{
      Geolocation.Providers.GoogleGeocoding => is_nil(google_geocoding_api_key!())
    }

    preferred_geocoding_providers!() |> Enum.reject(&disabled_providers[&1])
  end

  @doc """
  Validates admin authentication config, raises if invalid.
  """
  @spec validate_admin_authentication!() :: :ok | no_return()
  def validate_admin_authentication! do
    if admin_authentication_disabled?() do
      :ok
    else
      admin_jwk!()
      :ok
    end
  end
end
