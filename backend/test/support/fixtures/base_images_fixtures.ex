#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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
  def base_image_collection_fixture(system_model, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        handle: unique_base_image_collection_handle(),
        name: unique_base_image_collection_name()
      })

    {:ok, base_image_collection} =
      Edgehog.BaseImages.create_base_image_collection(system_model, attrs)

    base_image_collection
  end
end
