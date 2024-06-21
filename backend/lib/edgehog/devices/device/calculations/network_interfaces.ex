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

defmodule Edgehog.Devices.Device.Calculations.NetworkInterfaces do
  use Ash.Resource.Calculation

  @network_interface Application.compile_env(
                       :edgehog,
                       :astarte_network_interface_module,
                       Edgehog.Astarte.Device.NetworkInterface
                     )

  @impl true
  def load(_query, _opts, _context) do
    [:device_id, :appengine_client]
  end

  @impl true
  def calculate(devices, _opts, _context) do
    Enum.map(devices, fn device ->
      %{
        device_id: device_id,
        appengine_client: appengine_client
      } = device

      with :ok <- validate_appengine_client_exist(appengine_client),
           {:ok, network_interfaces} <- @network_interface.get(appengine_client, device_id) do
        Enum.map(network_interfaces, &parse_network_interface/1)
      else
        {:error, _reason} -> nil
      end
    end)
  end

  defp validate_appengine_client_exist(nil), do: {:error, :appengine_client_not_loaded}
  defp validate_appengine_client_exist(_), do: :ok

  defp parse_network_interface(network_interface) do
    attrs = Map.from_struct(network_interface)

    Edgehog.Devices.Device.NetworkInterface
    |> Ash.Changeset.for_create(:create, attrs, domain: Edgehog.Devices)
    |> Ash.create!()
  end
end
