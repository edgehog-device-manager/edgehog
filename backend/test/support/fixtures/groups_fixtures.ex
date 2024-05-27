#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule Edgehog.GroupsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Groups` context.
  """

  @doc """
  Generate a unique device_group handle.
  """
  def unique_device_group_handle, do: "test-devices#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique device_group name.
  """
  def unique_device_group_name, do: "Test Devices#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique device_group selector.
  """
  def unique_device_group_selector, do: ~s<"test#{System.unique_integer([:positive])}" in tags>

  @doc """
  Generate a device_group.
  """
  def device_group_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params =
      Enum.into(opts, %{
        handle: opts[:handle] || unique_device_group_handle(),
        name: opts[:name] || unique_device_group_name(),
        selector: opts[:selector] || unique_device_group_selector()
      })

    Edgehog.Groups.DeviceGroup
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end
end
