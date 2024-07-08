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

defmodule Edgehog.Astarte.Device.NetworkInterface do
  @moduledoc false
  @behaviour Edgehog.Astarte.Device.NetworkInterface.Behaviour

  alias Astarte.Client.AppEngine

  @type t :: %__MODULE__{
          name: String.t(),
          mac_address: String.t() | nil,
          technology: String.t() | nil
        }

  @enforce_keys [:name, :mac_address, :technology]
  defstruct @enforce_keys

  @interface "io.edgehog.devicemanager.NetworkInterfaceProperties"

  @impl Edgehog.Astarte.Device.NetworkInterface.Behaviour
  def get(%AppEngine{} = client, device_id) do
    with {:ok, %{"data" => data}} <-
           AppEngine.Devices.get_properties_data(client, device_id, @interface) do
      interfaces = parse_data(data)

      {:ok, interfaces}
    end
  end

  def parse_data(data), do: Enum.map(data, &parse_interface_properties/1)

  def parse_interface_properties({interface_name, properties_data}) do
    %__MODULE__{
      name: interface_name,
      mac_address: properties_data["macAddress"],
      technology: properties_data["technologyType"]
    }
  end
end
