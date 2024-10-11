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

defmodule Edgehog.Astarte.Device.AvailableContainers do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.AvailableContainers.Behaviour

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailableContainers.ContainerStatus

  @interface "io.edgehog.devicemanager.apps.AvailableContainers"

  @impl Edgehog.Astarte.Device.AvailableContainers.Behaviour
  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_properties_data(client, device_id, @interface) do
      containers = parse_data(data)

      {:ok, containers}
    end
  end

  def parse_data(data), do: Enum.map(data, &parse_container_status/1)

  def parse_container_status({container_id, properties_data}) do
    %ContainerStatus{
      id: container_id,
      status: properties_data["status"]
    }
  end
end
