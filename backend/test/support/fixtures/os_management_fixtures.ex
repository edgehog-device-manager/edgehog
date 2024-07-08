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

defmodule Edgehog.OSManagementFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.OSManagement` context.
  """

  alias Edgehog.BaseImagesFixtures
  alias Edgehog.DevicesFixtures
  alias Edgehog.OSManagement.OTAOperation

  @doc """
  Generate a manual ota_operation.
  """
  def manual_ota_operation_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant] |> DevicesFixtures.device_fixture() |> Map.fetch!(:id)
      end)

    params =
      Enum.into(opts, %{
        manual?: true,
        base_image_url: "https://my.bucket.example/ota.bin",
        device_id: device_id
      })

    OTAOperation
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generate a managed ota_operation.
  """
  def managed_ota_operation_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant] |> DevicesFixtures.device_fixture() |> Map.fetch!(:id)
      end)

    base_image = BaseImagesFixtures.base_image_fixture(tenant: tenant)

    params =
      Enum.into(opts, %{base_image_url: base_image.url, device_id: device_id})

    OTAOperation
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
    |> Ash.create!()
  end
end
