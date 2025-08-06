#
# This file is part of Edgehog.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule Edgehog.Astarte.Trigger.AstarteDataLayer do
  @moduledoc false
  @behaviour Edgehog.Astarte.Trigger.DataLayer

  alias Astarte.Client.RealmManagement
  alias Edgehog.Astarte.Trigger.DataLayer

  @impl DataLayer
  def get(%RealmManagement{} = client, trigger_name) do
    RealmManagement.Triggers.get(client, trigger_name)
  end

  @impl DataLayer
  def list(%RealmManagement{} = client) do
    RealmManagement.Triggers.list(client)
  end

  @impl DataLayer
  def create(%RealmManagement{} = client, trigger_json) do
    RealmManagement.Triggers.create(client, trigger_json)
  end

  @impl DataLayer
  def delete(%RealmManagement{} = client, trigger_name) do
    RealmManagement.Triggers.delete(client, trigger_name)
  end
end
