#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind
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

defmodule Edgehog.DevicesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Devices` context.
  """

  @doc """
  Generate a device.
  """
  def device_fixture(realm, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        device_id: "some device_id",
        name: "some name"
      })

    {:ok, device} = Edgehog.Devices.create_device(realm, attrs)

    device
  end
end
