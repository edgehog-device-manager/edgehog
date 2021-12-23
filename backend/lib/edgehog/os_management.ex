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

  alias Edgehog.OSManagement.OTAOperation

  @doc """
  Returns the list of ota_operations.

  ## Examples

      iex> list_ota_operations()
      [%OTAOperation{}, ...]

  """
  def list_ota_operations do
    Repo.all(OTAOperation)
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
  def get_ota_operation!(id), do: Repo.get!(OTAOperation, id)

  @doc """
  Creates a ota_operation.

  ## Examples

      iex> create_ota_operation(%{field: value})
      {:ok, %OTAOperation{}}

      iex> create_ota_operation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ota_operation(attrs \\ %{}) do
    %OTAOperation{}
    |> OTAOperation.changeset(attrs)
    |> Repo.insert()
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
    ota_operation
    |> OTAOperation.changeset(attrs)
    |> Repo.update()
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
    OTAOperation.changeset(ota_operation, attrs)
  end
end
