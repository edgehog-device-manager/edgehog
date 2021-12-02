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

defmodule EdgehogWeb.Resolvers.Appliances do
  alias Edgehog.Appliances
  alias Edgehog.Appliances.HardwareType
  alias Edgehog.Appliances.ApplianceModel

  def find_hardware_type(%{id: id}, _resolution) do
    Appliances.fetch_hardware_type(id)
  end

  def list_hardware_types(_parent, _args, _context) do
    {:ok, Appliances.list_hardware_types()}
  end

  def extract_hardware_type_part_numbers(
        %HardwareType{part_numbers: part_numbers},
        _args,
        _context
      ) do
    part_numbers = Enum.map(part_numbers, &Map.get(&1, :part_number))

    {:ok, part_numbers}
  end

  def create_hardware_type(_parent, attrs, _context) do
    with {:ok, hardware_type} <- Appliances.create_hardware_type(attrs) do
      {:ok, %{hardware_type: hardware_type}}
    end
  end

  def update_hardware_type(_parent, %{hardware_type_id: id} = attrs, _context) do
    with {:ok, %HardwareType{} = hardware_type} <- Appliances.fetch_hardware_type(id),
         {:ok, %HardwareType{} = hardware_type} <-
           Appliances.update_hardware_type(hardware_type, attrs) do
      {:ok, %{hardware_type: hardware_type}}
    end
  end

  def find_appliance_model(%{id: id}, %{context: context}) do
    with {:ok, appliance_model} <- Appliances.fetch_appliance_model(id) do
      appliance_model = localize_appliance_model_description(appliance_model, context)
      {:ok, appliance_model}
    end
  end

  def list_appliance_models(_parent, _args, %{context: context}) do
    appliance_models =
      Appliances.list_appliance_models()
      |> localize_appliance_model_description(context)

    {:ok, appliance_models}
  end

  defp localize_appliance_model_description(target, %{locale: locale}) do
    # Explicit locale, use that one
    Appliances.preload_localized_descriptions_for_appliance_model(target, locale)
  end

  defp localize_appliance_model_description(target, %{current_tenant: tenant}) do
    # Fallback
    %{default_locale: default_locale} = tenant

    Appliances.preload_localized_descriptions_for_appliance_model(target, default_locale)
  end

  def extract_appliance_model_part_numbers(
        %ApplianceModel{part_numbers: part_numbers},
        _args,
        _context
      ) do
    part_numbers = Enum.map(part_numbers, &Map.get(&1, :part_number))

    {:ok, part_numbers}
  end

  def create_appliance_model(_parent, %{hardware_type_id: hw_type_id} = attrs, %{
        context: %{current_tenant: current_tenant}
      }) do
    default_locale = current_tenant.default_locale

    with {:ok, hardware_type} <- Appliances.fetch_hardware_type(hw_type_id),
         :ok <- check_description_locale(attrs[:description], default_locale),
         attrs = wrap_description(attrs),
         {:ok, appliance_model} <-
           Appliances.create_appliance_model(hardware_type, attrs) do
      appliance_model =
        appliance_model
        |> Appliances.preload_localized_descriptions_for_appliance_model(default_locale)

      {:ok, %{appliance_model: appliance_model}}
    end
  end

  def update_appliance_model(_parent, %{appliance_model_id: id} = attrs, %{
        context: %{current_tenant: current_tenant}
      }) do
    default_locale = current_tenant.default_locale

    with {:ok, %ApplianceModel{} = appliance_model} <- Appliances.fetch_appliance_model(id),
         :ok <- check_description_locale(attrs[:description], default_locale),
         attrs = wrap_description(attrs),
         appliance_model =
           appliance_model
           |> Appliances.preload_localized_descriptions_for_appliance_model(default_locale),
         {:ok, %ApplianceModel{} = appliance_model} <-
           Appliances.update_appliance_model(appliance_model, attrs) do
      appliance_model =
        appliance_model
        |> Appliances.preload_localized_descriptions_for_appliance_model(default_locale)

      {:ok, %{appliance_model: appliance_model}}
    end
  end

  # Only allow a description that uses the tenant default locale in {create,update}_appliance_model
  defp check_description_locale(nil, _default_locale), do: :ok
  defp check_description_locale(%{locale: default_locale}, default_locale), do: :ok
  defp check_description_locale(%{locale: _other}, _default), do: {:error, :not_default_locale}

  # If it's there, wraps description to descriptions, as {create,update}_appliance_model expects a list
  defp wrap_description(%{description: description} = attrs) do
    attrs
    |> Map.delete(:description)
    |> Map.put(:descriptions, [description])
  end

  defp wrap_description(attrs), do: attrs

  def extract_localized_description(%ApplianceModel{descriptions: descriptions}, %{}, _context) do
    # We should always either 0 or 1 description here since the upper layer should take care
    # of only preloading the localized description.
    case descriptions do
      [description] -> {:ok, description}
      _ -> {:ok, nil}
    end
  end
end
