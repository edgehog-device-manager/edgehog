#
# This file is part of Edgehog.
#
# Copyright 2024-2025 SECO Mind Srl
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

defmodule Edgehog.Devices.Device.Calculations.AstarteInterfaceValue do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation

  @impl Calculation
  def load(_query, _opts, _context) do
    [:device_id, :appengine_client]
  end

  @impl Calculation
  def calculate(devices, opts, _context) do
    Enum.map(devices, fn device ->
      %{
        device_id: device_id,
        appengine_client: client
      } = device

      fetch_fun = value_id_to_fetch_fun(opts[:value_id])

      case fetch_fun.(client, device_id) do
        {:ok, result} -> result
        {:error, _reason} -> nil
      end
    end)
  end

  @available_containers Application.compile_env(
                          :edgehog,
                          :astarte_available_containers_module,
                          Edgehog.Astarte.Device.AvailableContainers
                        )
  @available_images Application.compile_env(
                      :edgehog,
                      :astarte_available_images_module,
                      Edgehog.Astarte.Device.AvailableImages
                    )
  @available_deployments Application.compile_env(
                           :edgehog,
                           :astarte_available_deployments_module,
                           Edgehog.Astarte.Device.AvailableDeployments
                         )
  @available_networks Application.compile_env(
                        :edgehog,
                        :astarte_available_networks_module,
                        Edgehog.Astarte.Device.AvailableNetworks
                      )

  @available_volumes Application.compile_env(
                       :edgehog,
                       :astarte_available_volumes_module,
                       Edgehog.Astarte.Device.AvailableVolumes
                     )

  @available_device_mappings Application.compile_env(
                               :edgehog,
                               :astarte_available_device_mappings_module,
                               Edgehog.Astarte.Device.AvailableDeviceMappings
                             )

  @base_image Application.compile_env(
                :edgehog,
                :astarte_base_image_module,
                Edgehog.Astarte.Device.BaseImage
              )

  @cellular_connection Application.compile_env(
                         :edgehog,
                         :astarte_cellular_connection_module,
                         Edgehog.Astarte.Device.CellularConnection
                       )

  @hardware_info Application.compile_env(
                   :edgehog,
                   :astarte_hardware_info_module,
                   Edgehog.Astarte.Device.HardwareInfo
                 )

  @os_info Application.compile_env(
             :edgehog,
             :astarte_os_info_module,
             Edgehog.Astarte.Device.OSInfo
           )

  @runtime_info Application.compile_env(
                  :edgehog,
                  :astarte_runtime_info_module,
                  Edgehog.Astarte.Device.RuntimeInfo
                )

  @storage_usage Application.compile_env(
                   :edgehog,
                   :astarte_storage_usage_module,
                   Edgehog.Astarte.Device.StorageUsage
                 )

  @system_status Application.compile_env(
                   :edgehog,
                   :astarte_system_status_module,
                   Edgehog.Astarte.Device.SystemStatus
                 )

  @wifi_scan_result Application.compile_env(
                      :edgehog,
                      :astarte_wifi_scan_result_module,
                      Edgehog.Astarte.Device.WiFiScanResult
                    )

  defp value_id_to_fetch_fun(:available_containers), do: &@available_containers.get/2
  defp value_id_to_fetch_fun(:available_deployments), do: &@available_deployments.get/2
  defp value_id_to_fetch_fun(:available_images), do: &@available_images.get/2
  defp value_id_to_fetch_fun(:available_volumes), do: &@available_volumes.get/2
  defp value_id_to_fetch_fun(:available_networks), do: &@available_networks.get/2
  defp value_id_to_fetch_fun(:available_device_mappings), do: &@available_device_mappings.get/2
  defp value_id_to_fetch_fun(:base_image_info), do: &@base_image.get/2
  defp value_id_to_fetch_fun(:hardware_info), do: &@hardware_info.get/2
  defp value_id_to_fetch_fun(:modem_properties), do: &@cellular_connection.get_modem_properties/2
  defp value_id_to_fetch_fun(:modem_status), do: &@cellular_connection.get_modem_status/2
  defp value_id_to_fetch_fun(:os_info), do: &@os_info.get/2
  defp value_id_to_fetch_fun(:runtime_info), do: &@runtime_info.get/2
  defp value_id_to_fetch_fun(:storage_usage), do: &@storage_usage.get/2
  defp value_id_to_fetch_fun(:system_status), do: &@system_status.get/2
  defp value_id_to_fetch_fun(:wifi_scan_result), do: &@wifi_scan_result.get/2
end
