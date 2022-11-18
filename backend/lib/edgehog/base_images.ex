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

defmodule Edgehog.BaseImages do
  @moduledoc """
  The BaseImages context.
  """

  import Ecto.Query, warn: false
  alias Edgehog.Repo

  alias Edgehog.BaseImages.BaseImageCollection

  @doc """
  Returns the list of base_image_collections.

  ## Examples

      iex> list_base_image_collections()
      [%BaseImageCollection{}, ...]

  """
  def list_base_image_collections do
    Repo.all(BaseImageCollection)
  end

  @doc """
  Gets a single base_image_collection.

  Raises `Ecto.NoResultsError` if the Base image collection does not exist.

  ## Examples

      iex> get_base_image_collection!(123)
      %BaseImageCollection{}

      iex> get_base_image_collection!(456)
      ** (Ecto.NoResultsError)

  """
  def get_base_image_collection!(id), do: Repo.get!(BaseImageCollection, id)

  @doc """
  Creates a base_image_collection.

  ## Examples

      iex> create_base_image_collection(%{field: value})
      {:ok, %BaseImageCollection{}}

      iex> create_base_image_collection(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_base_image_collection(attrs \\ %{}) do
    %BaseImageCollection{}
    |> BaseImageCollection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a base_image_collection.

  ## Examples

      iex> update_base_image_collection(base_image_collection, %{field: new_value})
      {:ok, %BaseImageCollection{}}

      iex> update_base_image_collection(base_image_collection, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_base_image_collection(%BaseImageCollection{} = base_image_collection, attrs) do
    base_image_collection
    |> BaseImageCollection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a base_image_collection.

  ## Examples

      iex> delete_base_image_collection(base_image_collection)
      {:ok, %BaseImageCollection{}}

      iex> delete_base_image_collection(base_image_collection)
      {:error, %Ecto.Changeset{}}

  """
  def delete_base_image_collection(%BaseImageCollection{} = base_image_collection) do
    Repo.delete(base_image_collection)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking base_image_collection changes.

  ## Examples

      iex> change_base_image_collection(base_image_collection)
      %Ecto.Changeset{data: %BaseImageCollection{}}

  """
  def change_base_image_collection(%BaseImageCollection{} = base_image_collection, attrs \\ %{}) do
    BaseImageCollection.changeset(base_image_collection, attrs)
  end
end
