#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.Astarte.Realm.Calculations.RealmManagementClient do
  use Ash.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:cluster]
  end

  @impl true
  def calculate(realms, _opts, _context) do
    Enum.map(realms, fn realm ->
      %{
        name: realm_name,
        private_key: private_key,
        cluster: %{
          base_api_url: base_api_url
        }
      } = realm

      case Astarte.Client.RealmManagement.new(base_api_url, realm_name, private_key: private_key) do
        {:ok, client} -> client
        _error -> nil
      end
    end)
  end
end