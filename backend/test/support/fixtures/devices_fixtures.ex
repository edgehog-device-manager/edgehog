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

defmodule Edgehog.DevicesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Devices` context.
  """

  alias Edgehog.Astarte
  alias Edgehog.AstarteFixtures
  alias Edgehog.Devices
  alias Edgehog.Devices.Device
  alias Edgehog.Repo

  @doc """
  Generate a unique hardware_type handle.
  """
  def unique_hardware_type_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique hardware_type name.
  """
  def unique_hardware_type_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique hardware_type part_number.
  """
  def unique_hardware_type_part_number, do: "1234-rev#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique system_model handle.
  """
  def unique_system_model_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique system_model name.
  """
  def unique_system_model_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique system_model part_number.
  """
  def unique_system_model_part_number, do: "1234-rev#{System.unique_integer([:positive])}"

  @doc """
  Generate a %Devices.Device{}.
  """
  def device_fixture(realm, attrs \\ %{}) do
    # The Devices context does not (currently) have a create functions since devices are always
    # created by Astarte, so we directly call Repo functions passing attrs as-is and preloading
    # what gets usually preloaded in %Devices.Device{}
    attrs = Enum.into(attrs, %{})

    %Device{
      realm_id: realm.id,
      device_id: AstarteFixtures.random_device_id(),
      name: "some name"
    }
    |> Map.merge(attrs)
    |> Repo.insert!()
    |> Edgehog.Repo.preload_defaults()
  end

  @doc """
  Generate a %Devices.Device{} compatible with a specific %BaseImages.BaseImage{}, passed as argument.
  """
  def device_fixture_compatible_with(base_image) do
    [%{part_number: part_number} | _] = base_image.base_image_collection.system_model.part_numbers

    {:ok, device} =
      astarte_device_fixture()
      |> Astarte.update_device(%{part_number: part_number})

    # Retrieve the updated device from the Devices context
    Devices.get_device!(device.id)
  end

  @doc """
  Generate a hardware_type.
  """
  def hardware_type_fixture(attrs \\ %{}) do
    {:ok, hardware_type} =
      attrs
      |> Enum.into(%{
        handle: unique_hardware_type_handle(),
        name: unique_hardware_type_name(),
        part_numbers: [unique_hardware_type_part_number()]
      })
      |> Edgehog.Devices.create_hardware_type()

    hardware_type
  end

  @doc """
  Generate a system_model.
  """
  def system_model_fixture(hardware_type, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        handle: unique_system_model_handle(),
        name: unique_system_model_name(),
        part_numbers: [unique_system_model_part_number()]
      })

    {:ok, system_model} = Edgehog.Devices.create_system_model(hardware_type, attrs)

    system_model
  end

  @doc """
  Adds tags to a %Devices.Device{}
  """
  def add_tags(device, tags) do
    {:ok, device} = Devices.update_device(device, %{tags: tags})
    device
  end

  defp astarte_device_fixture do
    # Helper to avoid having to manually create the cluster and realm
    # TODO: this will be eliminated once we have proper lazy fixtures (see issue #267)

    AstarteFixtures.cluster_fixture()
    |> AstarteFixtures.realm_fixture()
    |> AstarteFixtures.astarte_device_fixture()
  end
end
