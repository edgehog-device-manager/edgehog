#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule Edgehog.BaseImagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.BaseImages` context.
  """

  alias Edgehog.DevicesFixtures

  @doc """
  Generate a unique base_image_collection handle.
  """
  def unique_base_image_collection_handle, do: "some-handle#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique base_image_collection name.
  """
  def unique_base_image_collection_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a base_image_collection.
  """
  def base_image_collection_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {system_model_id, opts} =
      Keyword.pop_lazy(opts, :system_model_id, fn ->
        [tenant: tenant] |> DevicesFixtures.system_model_fixture() |> Map.fetch!(:id)
      end)

    params =
      Enum.into(opts, %{
        handle: unique_base_image_collection_handle(),
        name: unique_base_image_collection_name(),
        system_model_id: system_model_id
      })

    Edgehog.BaseImages.BaseImageCollection
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generate a unique base_image version.
  """
  def unique_base_image_version, do: "1.0.#{System.unique_integer([:positive])}"

  @doc """
  Generate a base_image.
  """
  def base_image_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {base_image_collection_id, opts} =
      Keyword.pop_lazy(opts, :base_image_collection_id, fn ->
        [tenant: tenant] |> base_image_collection_fixture() |> Map.fetch!(:id)
      end)

    params =
      Enum.into(opts, %{
        version: unique_base_image_version(),
        url: "https://example.com/ota.bin",
        base_image_collection_id: base_image_collection_id
      })

    Edgehog.BaseImages.BaseImage
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
    |> Ash.create!()
  end
end
