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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Config.GeolocationProviders do
  use Skogsra.Type

  @providers %{
    "device" => Edgehog.Geolocation.Providers.DeviceGeolocation,
    "ipbase" => Edgehog.Geolocation.Providers.IPBase,
    "google" => Edgehog.Geolocation.Providers.GoogleGeolocation
  }

  @impl Skogsra.Type
  def cast(value)

  def cast(value) when is_binary(value) do
    list =
      value
      |> String.split(~r/,/)
      |> Stream.map(&String.trim/1)
      |> Stream.map(&String.downcase/1)
      |> Stream.map(&@providers[&1])
      |> Stream.reject(&is_nil/1)
      |> Enum.to_list()

    {:ok, list}
  end

  def cast(value) when is_list(value) do
    if Enum.all?(value, &is_atom/1), do: {:ok, value}, else: :error
  end

  def cast(_) do
    :error
  end
end
