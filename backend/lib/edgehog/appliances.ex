#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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
  alias Ecto.Multi
  alias Edgehog.Repo

  alias Edgehog.Appliances.ApplianceModel
  alias Edgehog.Appliances.ApplianceModelPartNumber
  alias Edgehog.Appliances.HardwareType
  alias Edgehog.Appliances.HardwareTypePartNumber

  @doc """
  Returns the list of hardware_types.

  ## Examples

      iex> list_hardware_types()
      [%HardwareType{}, ...]

  """
  def list_hardware_types do
    Repo.all(HardwareType)
    |> Repo.preload(:part_numbers)
  end

  @doc """
  Gets a single hardware_type.

  Returns `{:error, :not_found}` if the Hardware type does not exist.

  ## Examples

      iex> fetch_hardware_type(123)
      {:ok, %HardwareType{}}

      iex> fetch_hardware_type(456)
      {:error, :not_found}

  """
  def fetch_hardware_type(id) do
    case Repo.get(HardwareType, id) do
      %HardwareType{} = hardware_type ->
        {:ok, Repo.preload(hardware_type, :part_numbers)}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Creates a hardware_type.

  ## Examples

      iex> create_hardware_type(%{field: value})
      {:ok, %HardwareType{}}

      iex> create_hardware_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_hardware_type(attrs \\ %{}) do
    {part_numbers, attrs} = Map.pop(attrs, :part_numbers, [])

    changeset =
      %HardwareType{tenant_id: Repo.get_tenant_id()}
      |> HardwareType.changeset(attrs)

    Multi.new()
    |> Multi.run(:assoc_part_numbers, fn _repo, _changes ->
      {:ok,
       insert_or_get_part_numbers(HardwareTypePartNumber, changeset, part_numbers, required: true)}
    end)
    |> Multi.insert(:hardware_type, fn %{assoc_part_numbers: changeset} ->
      changeset
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{hardware_type: hardware_type}} ->
        {:ok, Repo.preload(hardware_type, :part_numbers)}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  defp insert_or_get_part_numbers(schema, changeset, part_numbers, opts \\ [])

  defp insert_or_get_part_numbers(_schema, changeset, [], opts) do
    if opts[:required] do
      Ecto.Changeset.add_error(changeset, :part_numbers, "are required")
    else
      changeset
    end
  end

  defp insert_or_get_part_numbers(schema, changeset, part_numbers, _opts) do
    timestamp =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    maps =
      Enum.map(
        part_numbers,
        &%{
          tenant_id: Repo.get_tenant_id(),
          part_number: &1,
          inserted_at: timestamp,
          updated_at: timestamp
        }
      )

    # TODO: check for conflicts (i.e. part numbers existing but associated with another hardware type)
    Repo.insert_all(schema, maps, on_conflict: :nothing)
    query = from pn in schema, where: pn.part_number in ^part_numbers
    part_numbers = Repo.all(query)

    Ecto.Changeset.put_assoc(changeset, :part_numbers, part_numbers)
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
    {part_numbers, attrs} = Map.pop(attrs, :part_numbers, [])

    changeset = HardwareType.changeset(hardware_type, attrs)

    Multi.new()
    |> Multi.run(:assoc_part_numbers, fn _repo, _changes ->
      {:ok, insert_or_get_part_numbers(HardwareTypePartNumber, changeset, part_numbers)}
    end)
    |> Multi.update(:hardware_type, fn %{assoc_part_numbers: changeset} ->
      changeset
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{hardware_type: hardware_type}} ->
        {:ok, Repo.preload(hardware_type, :part_numbers)}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
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

  @doc """
  Returns the list of appliance_models.

  ## Examples

      iex> list_appliance_models()
      [%ApplianceModel{}, ...]

  """
  def list_appliance_models do
    Repo.all(ApplianceModel)
    |> Repo.preload(:part_numbers)
  end

  @doc """
  Gets a single appliance_model.

  Raises `Ecto.NoResultsError` if the Appliance model does not exist.

  ## Examples

      iex> fetch_appliance_model(123)
      {:ok, %ApplianceModel{}}

      iex> fetch_appliance_model(456)
      {:error, :not_found}

  """
  def fetch_appliance_model(id) do
    case Repo.get(ApplianceModel, id) do
      %ApplianceModel{} = appliance ->
        {:ok, Repo.preload(appliance, [:part_numbers])}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Creates a appliance_model.

  ## Examples

      iex> create_appliance_model(%{field: value})
      {:ok, %ApplianceModel{}}

      iex> create_appliance_model(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_appliance_model(%HardwareType{id: hardware_type_id}, attrs \\ %{}) do
    {part_numbers, attrs} = Map.pop(attrs, :part_numbers, [])

    changeset =
      %ApplianceModel{tenant_id: Repo.get_tenant_id(), hardware_type_id: hardware_type_id}
      |> ApplianceModel.changeset(attrs)

    Multi.new()
    |> Multi.run(:assoc_part_numbers, fn _repo, _changes ->
      {:ok,
       insert_or_get_part_numbers(ApplianceModelPartNumber, changeset, part_numbers,
         required: true
       )}
    end)
    |> Multi.insert(:appliance_model, fn %{assoc_part_numbers: changeset} ->
      changeset
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{appliance_model: appliance_model}} ->
        {:ok, Repo.preload(appliance_model, :part_numbers)}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Updates a appliance_model.

  ## Examples

      iex> update_appliance_model(appliance_model, %{field: new_value})
      {:ok, %ApplianceModel{}}

      iex> update_appliance_model(appliance_model, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_appliance_model(%ApplianceModel{} = appliance_model, attrs) do
    {part_numbers, attrs} = Map.pop(attrs, :part_numbers, [])

    changeset = ApplianceModel.changeset(appliance_model, attrs)

    Multi.new()
    |> Multi.run(:assoc_part_numbers, fn _repo, _changes ->
      {:ok, insert_or_get_part_numbers(ApplianceModelPartNumber, changeset, part_numbers)}
    end)
    |> Multi.update(:appliance_model, fn %{assoc_part_numbers: changeset} ->
      changeset
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{appliance_model: appliance_model}} ->
        {:ok, Repo.preload(appliance_model, :part_numbers)}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Deletes a appliance_model.

  ## Examples

      iex> delete_appliance_model(appliance_model)
      {:ok, %ApplianceModel{}}

      iex> delete_appliance_model(appliance_model)
      {:error, %Ecto.Changeset{}}

  """
  def delete_appliance_model(%ApplianceModel{} = appliance_model) do
    Repo.delete(appliance_model)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking appliance_model changes.

  ## Examples

      iex> change_appliance_model(appliance_model)
      %Ecto.Changeset{data: %ApplianceModel{}}

  """
  def change_appliance_model(%ApplianceModel{} = appliance_model, attrs \\ %{}) do
    ApplianceModel.changeset(appliance_model, attrs)
  end
end
