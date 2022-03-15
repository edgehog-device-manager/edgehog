#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Mocks.Astarte.Device.DeviceStatus do
  @behaviour Edgehog.Astarte.Device.DeviceStatus.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.DeviceStatus
  alias Edgehog.Astarte.InterfaceVersion

  @impl true
  def get(%AppEngine{} = _client, _device_id) do
    device_status = %DeviceStatus{
      attributes: %{"attribute_key" => "attribute_value"},
      groups: ["test-devices"],
      introspection: %{
        "com.example.ExampleInterface" => %InterfaceVersion{major: 1, minor: 0}
      },
      last_connection: ~U[2021-11-15 10:44:57.432516Z],
      last_disconnection: ~U[2021-11-15 10:45:57.432516Z],
      last_seen_ip: "198.51.100.25",
      online: false
    }

    {:ok, device_status}
  end
end
