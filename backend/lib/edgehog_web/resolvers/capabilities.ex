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

defmodule EdgehogWeb.Resolvers.Capabilities do
  alias Edgehog.Astarte
  alias Edgehog.Capabilities
  alias Edgehog.Devices
  alias Edgehog.Devices.Device

  def list_device_capabilities(%Device{device_id: device_id} = device, _args, _context) do
    with {:ok, client} <- Devices.appengine_client_from_device(device),
         {:ok, introspection} <- Astarte.fetch_device_introspection(client, device_id),
         capabilities = Capabilities.from_introspection(introspection) do
      {:ok, capabilities}
    else
      _ -> {:ok, []}
    end
  end
end
