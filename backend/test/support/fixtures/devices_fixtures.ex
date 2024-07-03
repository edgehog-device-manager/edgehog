#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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
  def device_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {realm_id, opts} =
      Keyword.pop_lazy(opts, :realm_id, fn ->
        [tenant: tenant] |> AstarteFixtures.realm_fixture() |> Map.fetch!(:id)
      end)

    default_device_id = AstarteFixtures.random_device_id()

    params =
      Enum.into(opts, %{device_id: default_device_id, name: default_device_id, realm_id: realm_id})

    Edgehog.Devices.Device
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generate a %Devices.Device{} compatible with a specific %BaseImages.BaseImage{}, passed as argument.
  """
  def device_fixture_compatible_with(opts \\ []) do
    {base_image_id, opts} = Keyword.pop!(opts, :base_image_id)

    base_image =
      Ash.get!(Edgehog.BaseImages.BaseImage, base_image_id,
        load: [base_image_collection: [system_model: [part_numbers: :part_number]]],
        tenant: opts[:tenant]
      )

    [%{part_number: part_number} | _] = base_image.base_image_collection.system_model.part_numbers

    opts
    |> Keyword.put(:part_number, part_number)
    |> device_fixture()
  end

  @doc """
  Generate a hardware_type.
  """
  def hardware_type_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params =
      Enum.into(opts, %{
        handle: unique_hardware_type_handle(),
        name: unique_hardware_type_name(),
        part_numbers: [unique_hardware_type_part_number()]
      })

    Edgehog.Devices.HardwareType
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generate a system_model.
  """
  def system_model_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {hardware_type_id, opts} =
      Keyword.pop_lazy(opts, :hardware_type_id, fn ->
        [tenant: tenant]
        |> hardware_type_fixture()
        |> Map.fetch!(:id)
      end)

    params =
      Enum.into(opts, %{
        handle: unique_system_model_handle(),
        name: unique_system_model_name(),
        part_numbers: [unique_system_model_part_number()],
        hardware_type_id: hardware_type_id
      })

    Edgehog.Devices.SystemModel
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Adds tags to a %Devices.Device{}
  """
  def add_tags(device, tags) do
    device
    |> Ash.Changeset.for_update(:add_tags, %{tags: tags})
    |> Ash.update!()
  end
end
