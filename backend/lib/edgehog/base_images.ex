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

defmodule Edgehog.BaseImages do
  @moduledoc """
  The BaseImages context.
  """

  import Ecto.Query, warn: false
  alias Edgehog.Repo

  alias Ecto.Multi
  alias Edgehog.Devices
  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.BaseImages.BaseImageCollection
  alias Edgehog.BaseImages.BucketStorage

  @storage_module Application.compile_env(
                    :edgehog,
                    :base_images_storage_module,
                    BucketStorage
                  )

  @doc """
  Returns the list of base_image_collections.

  ## Examples

      iex> list_base_image_collections()
      [%BaseImageCollection{}, ...]

  """
  def list_base_image_collections do
    Repo.all(BaseImageCollection)
    |> Repo.preload_defaults()
  end

  @doc """
  Fetches a single base_image_collection.

  Returns `{:ok, base_image_collection}` or `{:error, :not_found}` if the Base image collection does not exist.

  ## Examples

      iex> fetch_base_image_collection(123)
      {:ok, %BaseImageCollection{}}

      iex> fetch_base_image_collection(456)
      {:error, :not_found}

  """
  def fetch_base_image_collection(id) do
    Repo.fetch(BaseImageCollection, id)
    |> Repo.preload_defaults_in_result()
  end

  @doc """
  Creates a base_image_collection.

  ## Examples

      iex> create_base_image_collection(%Devices.SystemModel{}, %{field: value})
      {:ok, %BaseImageCollection{}}

      iex> create_base_image_collection(%Devices.SystemModel{}, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_base_image_collection(%Devices.SystemModel{} = system_model, attrs \\ %{}) do
    changeset =
      %BaseImageCollection{system_model_id: system_model.id}
      |> BaseImageCollection.changeset(attrs)

    Repo.insert(changeset)
    |> Repo.preload_defaults_in_result()
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
    changeset = BaseImageCollection.changeset(base_image_collection, attrs)

    Repo.update(changeset)
    |> Repo.preload_defaults_in_result()
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
    |> Repo.preload_defaults_in_result()
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

  @doc """
  Returns the list of base_images.

  ## Examples

      iex> list_base_images()
      [%BaseImage{}, ...]

  """
  def list_base_images do
    Repo.all(BaseImage)
    |> Repo.preload_defaults()
  end

  @doc """
  Returns the list of base_images in a specific `%BaseImageCollection{}`.

  ## Examples

      iex> list_base_images_for_collection(base_image_collection)
      [%BaseImage{}, ...]

  """
  def list_base_images_for_collection(%BaseImageCollection{} = base_image_collection) do
    Ecto.assoc(base_image_collection, :base_images)
    |> Repo.all()
    |> Repo.preload_defaults()
  end

  @doc """
  Fetches a single base_image.

  Returns `{:error, :not_found}` if the Base image does not exist.

  ## Examples

      iex> fetch_base_image(123)
      {:ok, %BaseImage{}}

      iex> fetch_base_image(456)
      {:error, :not_found}

  """
  def fetch_base_image(id) do
    Repo.fetch(BaseImage, id)
    |> Repo.preload_defaults_in_result()
  end

  @doc """
  Creates a base_image.

  ## Examples

      iex> create_base_image(%BaseImageCollection{}, %{field: value})
      {:ok, %BaseImage{}}

      iex> create_base_image(%BaseImageCollection{}, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_base_image(%BaseImageCollection{} = base_image_collection, attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(:no_file_base_image, fn _changes ->
      %BaseImage{base_image_collection_id: base_image_collection.id}
      |> BaseImage.create_changeset(attrs)
    end)
    |> Multi.run(:image_upload, fn _repo, %{no_file_base_image: base_image} ->
      file = %Plug.Upload{} = attrs.file
      # If version is nil, the changeset will fail below
      @storage_module.store(base_image, file)
    end)
    |> Multi.update(:base_image, fn changes ->
      %{no_file_base_image: base_image, image_upload: url} = changes
      Ecto.Changeset.change(base_image, url: url)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{base_image: base_image}} ->
        {:ok, Repo.preload_defaults(base_image)}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Updates a base_image.

  ## Examples

      iex> update_base_image(base_image, %{field: new_value})
      {:ok, %BaseImage{}}

      iex> update_base_image(base_image, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_base_image(%BaseImage{} = base_image, attrs) do
    changeset = BaseImage.update_changeset(base_image, attrs)

    Repo.update(changeset)
    |> Repo.preload_defaults_in_result()
  end

  @doc """
  Deletes a base_image.

  ## Examples

      iex> delete_base_image(base_image)
      {:ok, %BaseImage{}}

      iex> delete_base_image(base_image)
      {:error, %Ecto.Changeset{}}

  """
  def delete_base_image(%BaseImage{} = base_image) do
    Multi.new()
    |> Multi.delete(:base_image, base_image)
    |> Multi.run(:image_deletion, fn _repo, %{base_image: base_image} ->
      # If version is nil, the changeset will fail below
      with :ok <- @storage_module.delete(base_image) do
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{base_image: base_image}} ->
        {:ok, Repo.preload_defaults(base_image)}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking base_image changes.

  ## Examples

      iex> change_base_image(base_image)
      %Ecto.Changeset{data: %BaseImage{}}

  """
  def change_base_image(%BaseImage{} = base_image, attrs \\ %{}) do
    BaseImage.update_changeset(base_image, attrs)
  end
end
