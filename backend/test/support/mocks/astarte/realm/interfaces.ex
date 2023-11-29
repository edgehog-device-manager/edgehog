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

defmodule Edgehog.Mocks.Astarte.Realm.Interfaces do
  @behaviour Edgehog.Astarte.Realm.Interfaces.Behaviour

  import Edgehog.AstarteFixtures
  alias Astarte.Client.RealmManagement

  @impl true
  def get(%RealmManagement{} = _client, interface_name, interface_major) do
    {:ok, %{"data" => interface_map_fixture(name: interface_name, major: interface_major)}}
  end

  @impl true
  def create(%RealmManagement{} = _client, _interface_json) do
    :ok
  end

  @impl true
  def update(%RealmManagement{} = _client, _interface_name, _interface_major, _interface_json) do
    :ok
  end
end
