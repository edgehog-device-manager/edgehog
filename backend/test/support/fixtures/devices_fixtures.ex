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

  alias Edgehog.AstarteFixtures
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
    |> Edgehog.Devices.preload_defaults_for_device()
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
end
