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

defmodule Edgehog.Astarte.Realm.Interfaces do
  @behaviour Edgehog.Astarte.Realm.Interfaces.Behaviour

  alias Astarte.Client.RealmManagement

  @impl true
  def get(%RealmManagement{} = client, interface_name, interface_major) do
    RealmManagement.Interfaces.get(client, interface_name, interface_major)
  end

  @impl true
  def create(%RealmManagement{} = client, interface_json) do
    RealmManagement.Interfaces.create(client, interface_json)
  end

  @impl true
  def update(%RealmManagement{} = client, interface_name, interface_major, interface_json) do
    RealmManagement.Interfaces.update(client, interface_name, interface_major, interface_json)
  end
end
