#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule EdgehogWeb.Resolvers.Devices do
  alias Edgehog.Devices
  alias Edgehog.Devices.Device
  alias Edgehog.Labeling.DeviceAttribute
  alias EdgehogWeb.Schema.VariantTypes

  def find_device(%{id: id}, _resolution) do
    device =
      Devices.get_device!(id)
      |> Devices.preload_astarte_resources_for_device()

    {:ok, device}
  end

  def list_devices(_parent, %{filter: filter}, _resolution) do
    devices =
      Devices.list_devices(filter)
      |> Devices.preload_astarte_resources_for_device()

    {:ok, devices}
  end

  def list_devices(_parent, _args, _resolution) do
    devices =
      Devices.list_devices()
      |> Devices.preload_astarte_resources_for_device()

    {:ok, devices}
  end

  def update_device(%{device_id: id} = attrs, _resolution) do
    device = Devices.get_device!(id)
    attrs = maybe_wrap_typed_values(attrs)

    with {:ok, device} <- Devices.update_device(device, attrs) do
      device = Devices.preload_astarte_resources_for_device(device)

      {:ok, %{device: device}}
    end
  end

  def extract_device_tags(%Device{tags: tags}, _args, _context) do
    tag_names = for t <- tags, do: t.name
    {:ok, tag_names}
  end

  def extract_attribute_type(%DeviceAttribute{typed_value: typed_value}, _args, _context) do
    {:ok, typed_value.type}
  end

  def extract_attribute_value(%DeviceAttribute{typed_value: typed_value}, _args, _context) do
    %Ecto.JSONVariant{type: type, value: value} = typed_value
    VariantTypes.encode_variant_value(type, value)
  end

  defp maybe_wrap_typed_values(%{custom_attributes: custom_attributes} = attrs)
       when is_list(custom_attributes) do
    wrapped_attributes =
      Enum.map(custom_attributes, fn attr ->
        %{
          namespace: namespace,
          key: key,
          type: type,
          value: value
        } = attr

        # Wrap type and value under the :typed_value key, as expected by the Ecto schema
        %{
          namespace: namespace,
          key: key,
          typed_value: %{type: type, value: value}
        }
      end)

    %{attrs | custom_attributes: wrapped_attributes}
  end

  defp maybe_wrap_typed_values(attrs), do: attrs
end
