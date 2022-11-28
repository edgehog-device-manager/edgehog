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
# SPDX-License-Identifier: Apache-2.0
#

defmodule EdgehogWeb.Resolvers.Devices do
  alias Edgehog.Devices
  alias Edgehog.Devices.Device
  alias Edgehog.Devices.HardwareType
  alias Edgehog.Devices.SystemModel
  alias Edgehog.Labeling.DeviceAttribute
  alias EdgehogWeb.Schema.VariantTypes

  @device_fields_querying_astarte [
    :capabilities,
    :hardware_info,
    :location,
    :storage_usage,
    :system_status,
    :wifi_scan_results,
    :battery_status,
    :base_image,
    :os_info,
    :cellular_connection,
    :runtime_info,
    :network_interfaces
  ]

  def find_device(%{id: id}, %{context: context} = resolution) do
    device =
      Devices.get_device!(id)
      |> preload_localized_system_model(context)
      |> maybe_preload_astarte_resources_for_device(resolution)

    {:ok, device}
  end

  def find_hardware_type(%{id: id}, _resolution) do
    Devices.fetch_hardware_type(id)
  end

  def list_hardware_types(_parent, _args, _context) do
    {:ok, Devices.list_hardware_types()}
  end

  def extract_hardware_type_part_numbers(
        %HardwareType{part_numbers: part_numbers},
        _args,
        _context
      ) do
    part_numbers = Enum.map(part_numbers, &Map.get(&1, :part_number))

    {:ok, part_numbers}
  end

  def list_devices(_parent, %{filter: filter}, %{context: context} = resolution) do
    devices =
      Devices.list_devices(filter)
      |> preload_localized_system_model(context)
      |> maybe_preload_astarte_resources_for_device(resolution)

    {:ok, devices}
  end

  def list_devices(_parent, _args, %{context: context} = resolution) do
    devices =
      Devices.list_devices()
      |> preload_localized_system_model(context)
      |> maybe_preload_astarte_resources_for_device(resolution)

    {:ok, devices}
  end

  def update_device(%{device_id: id} = attrs, %{context: context} = resolution) do
    device = Devices.get_device!(id)
    attrs = maybe_wrap_typed_values(attrs)

    with {:ok, device} <- Devices.update_device(device, attrs) do
      device =
        device
        |> preload_localized_system_model(context)
        |> maybe_preload_astarte_resources_for_device(resolution)

      {:ok, %{device: device}}
    end
  end

  def preload_localized_system_model(target, context) do
    descriptions_query =
      context
      |> Map.fetch!(:preferred_locales)
      |> Devices.localized_system_model_description_query()

    preload = [descriptions: descriptions_query, hardware_type: [], part_numbers: []]

    Devices.preload_system_model(target, preload: preload)
  end

  defp maybe_preload_astarte_resources_for_device(device, resolution) do
    # We project the resolution, i.e. we obtain all requested child fields
    selections = Absinthe.Resolution.project(resolution)

    # We have to create the MapSet at runtime, otherwise Dialyzer complains about missing opaqueness
    astarte_fields = MapSet.new(@device_fields_querying_astarte)

    # We preload Astarte resources only if we need one of the fields that require querying Astarte
    should_preload? =
      selections
      |> Enum.any?(&MapSet.member?(astarte_fields, &1.schema_node.identifier))

    if should_preload? do
      device
      |> Devices.preload_astarte_resources_for_device()
    else
      device
    end
  end

  def create_hardware_type(_parent, attrs, _context) do
    with {:ok, hardware_type} <- Devices.create_hardware_type(attrs) do
      {:ok, %{hardware_type: hardware_type}}
    end
  end

  def update_hardware_type(_parent, %{hardware_type_id: id} = attrs, _context) do
    with {:ok, %HardwareType{} = hardware_type} <- Devices.fetch_hardware_type(id),
         {:ok, %HardwareType{} = hardware_type} <-
           Devices.update_hardware_type(hardware_type, attrs) do
      {:ok, %{hardware_type: hardware_type}}
    end
  end

  def delete_hardware_type(%{hardware_type_id: id}, _context) do
    with {:ok, %HardwareType{} = hardware_type} <- Devices.fetch_hardware_type(id),
         {:ok, %HardwareType{} = hardware_type} <- Devices.delete_hardware_type(hardware_type) do
      {:ok, %{hardware_type: hardware_type}}
    end
  end

  def find_system_model(%{id: id}, %{context: context}) do
    with {:ok, system_model} <- Devices.fetch_system_model(id) do
      system_model = localize_system_model_description(system_model, context)
      {:ok, system_model}
    end
  end

  def list_system_models(_parent, _args, %{context: context}) do
    system_models =
      Devices.list_system_models()
      |> localize_system_model_description(context)

    {:ok, system_models}
  end

  defp localize_system_model_description(target, context) do
    %{preferred_locales: preferred_locales} = context
    Devices.preload_localized_descriptions_for_system_model(target, preferred_locales)
  end

  def extract_system_model_part_numbers(
        %SystemModel{part_numbers: part_numbers},
        _args,
        _context
      ) do
    part_numbers = Enum.map(part_numbers, &Map.get(&1, :part_number))

    {:ok, part_numbers}
  end

  def create_system_model(_parent, %{hardware_type_id: hw_type_id} = attrs, %{
        context: %{current_tenant: current_tenant} = context
      }) do
    default_locale = current_tenant.default_locale

    with {:ok, hardware_type} <- Devices.fetch_hardware_type(hw_type_id),
         :ok <- check_description_locale(attrs[:description], default_locale),
         attrs = wrap_description(attrs),
         {:ok, system_model} <-
           Devices.create_system_model(hardware_type, attrs) do
      system_model = localize_system_model_description(system_model, context)

      {:ok, %{system_model: system_model}}
    end
  end

  def update_system_model(_parent, %{system_model_id: id} = attrs, %{
        context: %{current_tenant: current_tenant} = context
      }) do
    default_locale = current_tenant.default_locale

    with {:ok, %SystemModel{} = system_model} <- Devices.fetch_system_model(id),
         :ok <- check_description_locale(attrs[:description], default_locale),
         attrs = wrap_description(attrs),
         system_model = localize_system_model_description(system_model, context),
         {:ok, %SystemModel{} = system_model} <-
           Devices.update_system_model(system_model, attrs) do
      system_model = localize_system_model_description(system_model, context)

      {:ok, %{system_model: system_model}}
    end
  end

  def delete_system_model(%{system_model_id: id}, %{context: context}) do
    with {:ok, %SystemModel{} = system_model} <- Devices.fetch_system_model(id),
         system_model = localize_system_model_description(system_model, context),
         {:ok, %SystemModel{} = system_model} <- Devices.delete_system_model(system_model) do
      {:ok, %{system_model: system_model}}
    end
  end

  # Only allow a description that uses the tenant default locale in {create,update}_system_model
  defp check_description_locale(nil, _default_locale), do: :ok
  defp check_description_locale(%{locale: default_locale}, default_locale), do: :ok
  defp check_description_locale(%{locale: _other}, _default), do: {:error, :not_default_locale}

  # If it's there, wraps description to descriptions, as {create,update}_system_model expects a list
  defp wrap_description(%{description: description} = attrs) do
    descriptions = Enum.reject([description], &(is_nil(&1) || String.trim(&1.text) == ""))

    attrs
    |> Map.delete(:description)
    |> Map.put(:descriptions, descriptions)
  end

  defp wrap_description(attrs), do: attrs

  def extract_localized_description(%SystemModel{descriptions: descriptions}, _args, %{
        context: %{preferred_locales: preferred_locales}
      })
      when is_list(descriptions) do
    locale_to_index_map =
      preferred_locales
      |> Enum.with_index()
      |> Enum.into(%{})

    description =
      descriptions
      |> Enum.sort_by(&Map.get(locale_to_index_map, &1.locale))
      |> List.first()

    {:ok, description}
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
