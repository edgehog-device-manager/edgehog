#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Config do
  @moduledoc """
  This module handles the configuration of Edgehog
  """
  use Skogsra
  alias Edgehog.Config.{GeocodingProviders, GeolocationProviders}
  alias Edgehog.Geolocation

  @envdoc "The API key for the freegeoip.app geolocation provider."
  app_env :freegeoip_api_key, :edgehog, :freegeoip_api_key,
    os_env: "FREEGEOIP_API_KEY",
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
  Possible values are: freegeoip, google
  """
  app_env :preferred_geolocation_providers, :edgehog, :preferred_geolocation_providers,
    os_env: "PREFERRED_GEOLOCATION_PROVIDERS",
    type: GeolocationProviders,
    default: [Geolocation.Providers.GoogleGeolocation, Geolocation.Providers.FreeGeoIP]

  @envdoc """
  A comma separated list of preferred geocoding providers.
  Possible values are: google
  """
  app_env :preferred_geocoding_providers, :edgehog, :preferred_geocoding_providers,
    os_env: "PREFERRED_GEOCODING_PROVIDERS",
    type: GeocodingProviders,
    default: [Geolocation.Providers.GoogleGeocoding]

  @doc """
  Returns the list of geolocation modules to use.
  """
  @spec geolocation_providers!() :: list(atom())
  def geolocation_providers! do
    disabled_providers = %{
      Edgehog.Geolocation.Providers.FreeGeoIp => is_nil(freegeoip_api_key!()),
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
end
