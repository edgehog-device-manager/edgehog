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

defmodule Edgehog.AppliancesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Appliances` context.
  """

  @doc """
  Generate a hardware_type.
  """
  def hardware_type_fixture(attrs \\ %{}) do
    {:ok, hardware_type} =
      attrs
      |> Enum.into(%{
        handle: "some-handle",
        name: "some name",
        part_numbers: ["ABC123"]
      })
      |> Edgehog.Appliances.create_hardware_type()

    hardware_type
  end

  @doc """
  Generate a appliance_model.
  """
  def appliance_model_fixture(attrs \\ %{}) do
    {:ok, appliance_model} =
      attrs
      |> Enum.into(%{
        handle: "some handle",
        name: "some name"
      })
      |> Edgehog.Appliances.create_appliance_model()

    appliance_model
  end
end
