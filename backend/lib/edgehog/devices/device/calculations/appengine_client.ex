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

defmodule Edgehog.Devices.Device.Calculations.AppEngineClient do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias Astarte.Client.AppEngine

  @impl Calculation
  def load(_query, _opts, _context) do
    [realm: [:name, :private_key, cluster: [:base_api_url]]]
  end

  @impl Calculation
  def calculate(devices, _opts, _context) do
    Enum.map(devices, fn device ->
      %{
        realm: %{
          name: realm_name,
          private_key: private_key,
          cluster: %{
            base_api_url: base_api_url
          }
        }
      } = device

      # TODO: scope client claims to the device
      case AppEngine.new(base_api_url, realm_name, private_key: private_key) do
        {:ok, client} -> client
        _error -> nil
      end
    end)
  end
end
