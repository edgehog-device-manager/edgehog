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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Devices do
  @moduledoc """
  The Devices context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Edgehog.Repo

  alias Edgehog.Devices.SystemModel
  alias Edgehog.Devices.SystemModelDescription
  alias Edgehog.Devices.SystemModelPartNumber
  alias Edgehog.Devices.HardwareType
  alias Edgehog.Devices.HardwareTypePartNumber
  alias Edgehog.Devices.Tag
  alias Edgehog.Assets

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
    hardware_type
    |> HardwareType.delete_changeset()
    |> Repo.delete()
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
  Returns the list of system_models.

  ## Examples

      iex> list_system_models()
      [%SystemModel{}, ...]

  """
  def list_system_models do
    Repo.all(SystemModel)
    |> Repo.preload([:part_numbers, :hardware_type])
  end

  @doc """
  Gets a single system_model.

  Raises `Ecto.NoResultsError` if the System Model does not exist.

  ## Examples

      iex> fetch_system_model(123)
      {:ok, %SystemModel{}}

      iex> fetch_system_model(456)
      {:error, :not_found}

  """
  def fetch_system_model(id) do
    case Repo.get(SystemModel, id) do
      %SystemModel{} = system ->
        {:ok, Repo.preload(system, [:part_numbers, :hardware_type])}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Preloads only descriptions with a specific locale for an `SystemModel` (or a list of them).
  """
  def preload_localized_descriptions_for_system_model(model_or_models, locale) do
    descriptions_preload = SystemModelDescription.localized(locale)

    Repo.preload(model_or_models, descriptions: descriptions_preload)
  end

  @doc """
  Returns a query that selects only `SystemModelDescription` with a specific locale.
  """
  def localized_system_model_description_query(locale) do
    SystemModelDescription.localized(locale)
  end

  @doc """
  Creates a system_model.

  ## Examples

      iex> create_system_model(%{field: value})
      {:ok, %SystemModel{}}

      iex> create_system_model(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_system_model(%HardwareType{id: hardware_type_id}, attrs \\ %{}) do
    {part_numbers, attrs} = Map.pop(attrs, :part_numbers, [])

    changeset =
      %SystemModel{tenant_id: Repo.get_tenant_id(), hardware_type_id: hardware_type_id}
      |> SystemModel.changeset(attrs)

    Multi.new()
    |> Multi.run(:assoc_part_numbers, fn _repo, _changes ->
      {:ok,
       insert_or_get_part_numbers(SystemModelPartNumber, changeset, part_numbers, required: true)}
    end)
    |> Multi.insert(:system_model, fn %{assoc_part_numbers: changeset} ->
      changeset
    end)
    |> Multi.run(:upload_system_model_picture, fn repo, %{system_model: system_model} ->
      with {:ok, picture_file} <- Ecto.Changeset.fetch_change(changeset, :picture_file),
           {:ok, picture_url} <-
             Assets.upload_system_model_picture(system_model, picture_file) do
        change_system_model(system_model, %{picture_url: picture_url})
        |> repo.update()
      else
        # No :picture_file, no need to change
        :error -> {:ok, system_model}
        # Storage is disabled, ignore for now
        {:error, :storage_disabled} -> {:ok, system_model}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{upload_system_model_picture: system_model}} ->
        {:ok, Repo.preload(system_model, [:part_numbers, :hardware_type])}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Updates a system_model.

  ## Examples

      iex> update_system_model(system_model, %{field: new_value})
      {:ok, %SystemModel{}}

      iex> update_system_model(system_model, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_system_model(%SystemModel{} = system_model, attrs) do
    {part_numbers, attrs} = Map.pop(attrs, :part_numbers, [])

    changeset =
      SystemModel.changeset(system_model, attrs)
      |> Ecto.Changeset.prepare_changes(fn changeset ->
        # This handles the case of picture deletion or update with URL
        case Ecto.Changeset.fetch_change(changeset, :picture_url) do
          {:ok, _nil_or_url} ->
            old_picture_url = changeset.data.picture_url

            # We do our best to delete the existing picture, if it's in the store
            _ = Assets.delete_system_model_picture(system_model, old_picture_url)

            changeset

          _ ->
            changeset
        end
      end)

    Multi.new()
    |> Multi.run(:assoc_part_numbers, fn _repo, _changes ->
      {:ok, insert_or_get_part_numbers(SystemModelPartNumber, changeset, part_numbers)}
    end)
    |> Multi.update(:system_model, fn %{assoc_part_numbers: changeset} ->
      changeset
    end)
    |> Multi.run(:upload_system_model_picture, fn repo, %{system_model: system_model} ->
      # This handles the case of picture update
      with {:ok, picture_file} <- Ecto.Changeset.fetch_change(changeset, :picture_file),
           {:ok, picture_url} <-
             Assets.upload_system_model_picture(system_model, picture_file) do
        # Retrieve the old picture, if any, from the original changeset
        old_picture_url = changeset.data.picture_url
        # Ignore the result here for now: a failure to delete the old picture shouldn't
        # compromise the success of the operation (we would leave another orphan image anyway)
        _ = Assets.delete_system_model_picture(system_model, old_picture_url)

        change_system_model(system_model, %{picture_url: picture_url})
        |> repo.update()
      else
        # No :picture_file, no need to change
        :error -> {:ok, system_model}
        # Storage is disabled, ignore for now
        {:error, :storage_disabled} -> {:ok, system_model}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{upload_system_model_picture: system_model}} ->
        {:ok, Repo.preload(system_model, [:part_numbers, :hardware_type])}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Deletes a system_model.

  ## Examples

      iex> delete_system_model(system_model)
      {:ok, %SystemModel{}}

      iex> delete_system_model(system_model)
      {:error, %Ecto.Changeset{}}

  """
  def delete_system_model(%SystemModel{} = system_model) do
    changeset = SystemModel.delete_changeset(system_model)

    with {:ok, system_model} <- Repo.delete(changeset) do
      # Delete the picture as well, if any.
      # Ignore the result, a failure to delete the picture shouldn't compromise the success of
      # the operation (we would leave another orphan image anyway)
      _ = Assets.delete_system_model_picture(system_model, system_model.picture_url)
      {:ok, system_model}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking system_model changes.

  ## Examples

      iex> change_system_model(system_model)
      %Ecto.Changeset{data: %SystemModel{}}

  """
  def change_system_model(%SystemModel{} = system_model, attrs \\ %{}) do
    SystemModel.changeset(system_model, attrs)
  end

  @doc """
  Inserts the tags passed in attrs within a multi transaction, normalizing them.

  Returns the updated `%Ecto.Multi{}`.
  """
  def ensure_tags_exist_multi(multi, %{tags: _tags} = attrs) do
    multi
    |> Multi.run(:cast_tags, fn _repo, _changes ->
      data = %{}
      types = %{tags: {:array, :string}}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(attrs, Map.keys(types))

      with {:ok, %{tags: tags}} <- Ecto.Changeset.apply_action(changeset, :insert) do
        tenant_id = Repo.get_tenant_id()

        now =
          NaiveDateTime.utc_now()
          |> NaiveDateTime.truncate(:second)

        tag_maps =
          for tag <- tags,
              tag = normalize_tag(tag),
              tag != "" do
            %{name: tag, inserted_at: now, updated_at: now, tenant_id: tenant_id}
          end

        {:ok, tag_maps}
      end
    end)
    |> Multi.insert_all(:insert_tags, Tag, & &1.cast_tags, on_conflict: :nothing)
    |> Multi.run(:ensure_tags_exist, fn repo, %{cast_tags: tag_maps} ->
      tag_names = for t <- tag_maps, do: t.name
      {:ok, repo.all(from t in Tag, where: t.name in ^tag_names)}
    end)
  end

  def ensure_tags_exist_multi(multi, _attrs) do
    # No tags in the update, so we return nil for tags
    Multi.run(multi, :ensure_tags_exist, fn _repo, _previous ->
      {:ok, nil}
    end)
  end

  defp normalize_tag(tag) do
    tag
    |> String.trim()
    |> String.downcase()
  end
end
