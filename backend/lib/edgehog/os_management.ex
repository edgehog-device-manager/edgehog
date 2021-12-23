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

defmodule Edgehog.OSManagement do
  @moduledoc """
  The OSManagement context.
  """

  import Ecto.Query, warn: false
  alias Edgehog.Repo

  alias Edgehog.Astarte
  alias Edgehog.OSManagement.OTAOperation

  @doc """
  Returns the list of ota_operations.

  ## Examples

      iex> list_ota_operations()
      [%OTAOperation{}, ...]

  """
  def list_ota_operations do
    Repo.all(OTAOperation)
    |> Repo.preload(:device)
  end

  @doc """
  Gets a single ota_operation.

  Raises `Ecto.NoResultsError` if the Ota operation does not exist.

  ## Examples

      iex> get_ota_operation!(123)
      %OTAOperation{}

      iex> get_ota_operation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ota_operation!(id) do
    Repo.get!(OTAOperation, id)
    |> Repo.preload(:device)
  end

  @doc """
  Creates a ota_operation.

  ## Examples

      iex> create_ota_operation(%Astarte.Device{} = device, %{field: value})
      {:ok, %OTAOperation{}}

      iex> create_ota_operation(%Astarte.Device{} = device, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ota_operation(%Astarte.Device{} = device, attrs \\ %{}) do
    changeset =
      %OTAOperation{}
      |> OTAOperation.create_changeset(attrs)
      |> Ecto.Changeset.put_assoc(:device, device)

    with {:ok, ota_operation} <- Repo.insert(changeset) do
      {:ok, Repo.preload(ota_operation, :device)}
    end
  end

  @doc """
  Updates a ota_operation.

  ## Examples

      iex> update_ota_operation(ota_operation, %{field: new_value})
      {:ok, %OTAOperation{}}

      iex> update_ota_operation(ota_operation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ota_operation(%OTAOperation{} = ota_operation, attrs) do
    changeset =
      ota_operation
      |> OTAOperation.update_changeset(attrs)

    with {:ok, ota_operation} <- Repo.update(changeset) do
      {:ok, Repo.preload(ota_operation, :device)}
    end
  end

  @doc """
  Deletes a ota_operation.

  ## Examples

      iex> delete_ota_operation(ota_operation)
      {:ok, %OTAOperation{}}

      iex> delete_ota_operation(ota_operation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ota_operation(%OTAOperation{} = ota_operation) do
    Repo.delete(ota_operation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ota_operation changes.

  ## Examples

      iex> change_ota_operation(ota_operation)
      %Ecto.Changeset{data: %OTAOperation{}}

  """
  def change_ota_operation(%OTAOperation{} = ota_operation, attrs \\ %{}) do
    OTAOperation.update_changeset(ota_operation, attrs)
  end
end
