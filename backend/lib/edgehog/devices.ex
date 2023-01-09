#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

  alias Edgehog.Assets
  alias Edgehog.Devices.Device
  alias Edgehog.Devices.SystemModel
  alias Edgehog.Devices.SystemModelPartNumber
  alias Edgehog.Devices.HardwareType
  alias Edgehog.Devices.HardwareTypePartNumber
  alias Edgehog.Labeling

  @doc """
  Gets a single device.

  Raises `Ecto.NoResultsError` if the Device does not exist.

  ## Examples

  iex> get_device!(123)
  %Device{}

  iex> get_device!(456)
  ** (Ecto.NoResultsError)

  """
  def get_device!(id) do
    Repo.get!(Device, id)
    |> preload_defaults_for_device()
  end

  @doc """
  Returns the list of devices.

  ## Examples

      iex> list_devices()
      [%Device{}, ...]

  """
  def list_devices(filters \\ %{}) do
    filters
    |> Enum.reduce(Device, &filter_with/2)
    |> Repo.all()
    |> preload_defaults_for_device()
  end

  @doc """
  Preloads the default associations for an Edgehog Device (or a list of devices)
  """
  def preload_defaults_for_device(device_or_devices) do
    Repo.preload(device_or_devices,
      tags: [],
      custom_attributes: [],
      system_model: [:hardware_type, :part_numbers]
    )
  end

  defp filter_with({:online, online}, query) do
    from q in query, where: q.online == ^online
  end

  defp filter_with({:device_id, device_id}, query) do
    from q in query, where: ilike(q.device_id, ^"%#{device_id}%")
  end

  defp filter_with({:system_model_part_number, part_number}, query) do
    from [system_model_part_number: smpn] in ensure_system_model_part_number(query),
      where: ilike(smpn.part_number, ^"%#{part_number}%")
  end

  defp filter_with({:system_model_handle, handle}, query) do
    from [system_model: sm] in ensure_system_model(query),
      where: ilike(sm.handle, ^"%#{handle}%")
  end

  defp filter_with({:system_model_name, name}, query) do
    from [system_model: sm] in ensure_system_model(query),
      where: ilike(sm.name, ^"%#{name}%")
  end

  defp filter_with({:hardware_type_part_number, part_number}, query) do
    from [hardware_type_part_number: htpn] in ensure_hardware_type_part_number(query),
      where: ilike(htpn.part_number, ^"%#{part_number}%")
  end

  defp filter_with({:hardware_type_handle, handle}, query) do
    from [hardware_type: ht] in ensure_hardware_type(query),
      where: ilike(ht.handle, ^"%#{handle}%")
  end

  defp filter_with({:hardware_type_name, name}, query) do
    from [hardware_type: ht] in ensure_hardware_type(query),
      where: ilike(ht.name, ^"%#{name}%")
  end

  defp filter_with({:tag, tag}, query) do
    device_ids_ilike_tag = Labeling.DeviceTag.device_ids_ilike_tag(tag)

    from q in query,
      where: q.id in subquery(device_ids_ilike_tag)
  end

  defp ensure_hardware_type(query) do
    if has_named_binding?(query, :hardware_type) do
      query
    else
      from [system_model: sm] in ensure_system_model(query),
        join: ht in assoc(sm, :hardware_type),
        as: :hardware_type
    end
  end

  defp ensure_hardware_type_part_number(query) do
    if has_named_binding?(query, :hardware_type_part_number) do
      query
    else
      from [hardware_type: ht] in ensure_hardware_type(query),
        join: htpn in assoc(ht, :part_numbers),
        as: :hardware_type_part_number
    end
  end

  defp ensure_system_model(query) do
    if has_named_binding?(query, :system_model) do
      query
    else
      from [system_model_part_number: smpn] in ensure_system_model_part_number(query),
        join: sm in assoc(smpn, :system_model),
        as: :system_model
    end
  end

  defp ensure_system_model_part_number(query) do
    if has_named_binding?(query, :system_model_part_number) do
      query
    else
      from q in query,
        join: smpn in assoc(q, :system_model_part_number),
        as: :system_model_part_number
    end
  end

  @doc """
  Preloads a system model for a resource (or a list of resources) associated with it.

  Supported options:
  - `:force` a boolean indicating if the preload has to be read from the database also if it's
  already populated. Defaults to `false`.
  - `:preload` the option passed to the preload, can be a query or a list of atoms. Defaults to `[]`.
  """
  def preload_system_model(target_resource, opts \\ []) do
    force = Keyword.get(opts, :force, false)
    preload = Keyword.get(opts, :preload, [])

    Repo.preload(target_resource, [system_model: preload], force: force)
  end

  @doc """
  Updates a device.

  ## Examples

  iex> update_device(device, %{field: new_value})
  {:ok, %Device{}}

  iex> update_device(device, %{field: bad_value})
  {:error, %Ecto.Changeset{}}

  """
  def update_device(%Device{} = device, attrs) do
    Multi.new()
    |> Labeling.ensure_tags_exist_multi(attrs)
    |> Multi.update(:update_device, fn
      %{ensure_tags_exist: nil} ->
        device
        |> Device.update_changeset(attrs)

      %{ensure_tags_exist: tags} when is_list(tags) ->
        device
        |> Device.update_changeset(attrs)
        |> Ecto.Changeset.put_assoc(:tags, tags)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_device: device}} ->
        {:ok, preload_defaults_for_device(device)}

      {:error, _failed_operation, failed_value, _progress_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Deletes a device.

  ## Examples

  iex> delete_device(device)
  {:ok, %Device{}}

  iex> delete_device(device)
  {:error, %Ecto.Changeset{}}

  """
  def delete_device(%Device{} = device) do
    Repo.delete(device)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking device changes.

  ## Examples

  iex> change_device(device)
  %Ecto.Changeset{data: %Device{}}

  """
  def change_device(%Device{} = device, attrs \\ %{}) do
    Device.update_changeset(device, attrs)
  end

  @doc """
  Preloads the Astarte realm and its cluster for an Edgehog Device.
  """
  def preload_astarte_resources_for_device(device_or_devices) do
    Repo.preload(device_or_devices, [realm: [:cluster]], skip_tenant_id: true)
  end

  @doc """
  Returns an `%Astarte.Client.AppEngine{}` for the given device.

  The device must have the Astarte realm and cluster preloaded, call preload_astarte_resources/1
  before calling this function to make sure of this.

  ## Examples

  iex> appengine_client_from_device(device)
  {:ok, %Astarte.Client.AppEngine{}}

  iex> appengine_client_from_device(device)
  {:error, :invalid_private_key}

  """
  def appengine_client_from_device(%Device{realm: %{cluster: cluster} = realm})
      when is_struct(realm, Edgehog.Astarte.Realm) and is_struct(cluster, Edgehog.Astarte.Cluster) do
    %{
      name: realm_name,
      private_key: private_key
    } = realm

    %{base_api_url: base_api_url} = cluster

    # TODO: this should create the client with a scoped JWT
    Astarte.Client.AppEngine.new(base_api_url, realm_name, private_key: private_key)
  end

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
      # TODO: this merges the updated descriptions with the existing ones to maintain the existing
      # behavior. Re-evaluate this when we support a proper description update API, considering
      # that, as it is, this doesn't allow to delete descriptions
      Ecto.Changeset.update_change(changeset, :description, fn updated_locales ->
        Map.merge(system_model.description || %{}, updated_locales)
      end)
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
    with {:ok, system_model} <- Repo.delete(system_model) do
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
end
