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

defmodule Edgehog.Appliances do
  @moduledoc """
  The Appliances context.
  """

  import Ecto.Query, warn: false
  alias Edgehog.Repo

  alias Edgehog.Appliances.HardwareType

  @doc """
  Returns the list of hardware_types.

  ## Examples

      iex> list_hardware_types()
      [%HardwareType{}, ...]

  """
  def list_hardware_types do
    Repo.all(HardwareType)
  end

  @doc """
  Gets a single hardware_type.

  Raises `Ecto.NoResultsError` if the Hardware type does not exist.

  ## Examples

      iex> get_hardware_type!(123)
      %HardwareType{}

      iex> get_hardware_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_hardware_type!(id), do: Repo.get!(HardwareType, id)

  @doc """
  Creates a hardware_type.

  ## Examples

      iex> create_hardware_type(%{field: value})
      {:ok, %HardwareType{}}

      iex> create_hardware_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_hardware_type(attrs \\ %{}) do
    %HardwareType{tenant_id: Repo.get_tenant_id()}
    |> HardwareType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a hardware_type.

  ## Examples

      iex> update_hardware_type(hardware_type, %{field: new_value})
      {:ok, %HardwareType{}}

      iex> update_hardware_type(hardware_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_hardware_type(%HardwareType{} = hardware_type, attrs) do
    hardware_type
    |> HardwareType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a hardware_type.

  ## Examples

      iex> delete_hardware_type(hardware_type)
      {:ok, %HardwareType{}}

      iex> delete_hardware_type(hardware_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_hardware_type(%HardwareType{} = hardware_type) do
    Repo.delete(hardware_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking hardware_type changes.

  ## Examples

      iex> change_hardware_type(hardware_type)
      %Ecto.Changeset{data: %HardwareType{}}

  """
  def change_hardware_type(%HardwareType{} = hardware_type, attrs \\ %{}) do
    HardwareType.changeset(hardware_type, attrs)
  end
end
