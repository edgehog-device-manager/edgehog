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

defmodule Edgehog.OSManagement do
  @moduledoc """
  The OSManagement context.
  """

  import Ecto.Query, warn: false
  alias Edgehog.Repo

  alias Ecto.Multi
  alias Edgehog.Astarte
  alias Edgehog.BaseImages
  alias Edgehog.Devices
  alias Edgehog.OSManagement.EphemeralImage
  alias Edgehog.OSManagement.OTAOperation

  require Logger

  @ephemeral_image_module Application.compile_env(
                            :edgehog,
                            :os_management_ephemeral_image_module,
                            EphemeralImage
                          )

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
  Returns the list of ota_operations for a specific Device.

  ## Examples

  iex> list_device_ota_operations(%Astarte.Device{})
  [%OTAOperation{}, ...]

  """
  def list_device_ota_operations(%Devices.Device{id: device_id}) do
    query =
      from o in OTAOperation,
        where: o.device_id == ^device_id

    Repo.all(query)
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
  Creates a OTAOperation by manually uploading an image.

  ## Examples

      iex> create_manual_ota_operation(%Astarte.Device{} = device, %Plug.Upload{})
      {:ok, %OTAOperation{}}
  """
  def create_manual_ota_operation(%Devices.Device{} = device, %Plug.Upload{} = base_image_file) do
    ota_operation_id = Ecto.UUID.generate()
    tenant_id = Repo.get_tenant_id()

    Multi.new()
    |> Multi.run(:image_upload, fn _repo, _changes ->
      @ephemeral_image_module.upload(tenant_id, ota_operation_id, base_image_file)
    end)
    |> Multi.run(:ota_operation, fn _repo, %{image_upload: base_image_url} ->
      ota_operation = %OTAOperation{
        id: ota_operation_id,
        base_image_url: base_image_url,
        device_id: device.id,
        manual?: true
      }

      Repo.insert(ota_operation)
    end)
    |> Multi.run(:send_ota_request, fn _repo, %{image_upload: base_image_url} ->
      device_id = device.device_id

      with {:ok, client} <- Devices.appengine_client_from_device(device),
           :ok <-
             Astarte.send_ota_request_update(client, device_id, ota_operation_id, base_image_url) do
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{ota_operation: ota_operation}} ->
        {:ok, Repo.preload(ota_operation, :device)}

      {:error, _failed_operation, failed_value, %{image_upload: base_image_url}} ->
        # If we fail after a successful upload, we at least try to clean up the upload
        @ephemeral_image_module.delete(tenant_id, ota_operation_id, base_image_url)
        {:error, failed_value}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
    end
  end

  @doc """
  Creates an OTAOperation using an existing `BaseImage`.

  ## Example

  iex> create_managed_ota_operation(%Devices.Device{} = device, %BaseImages.BaseImage{} = base_image)
  {:ok, %OTAOperation{}}
  """
  def create_managed_ota_operation(
        %Devices.Device{} = device,
        %BaseImages.BaseImage{} = base_image
      ) do
    ota_operation_id = Ecto.UUID.generate()

    Multi.new()
    |> Multi.insert(:ota_operation, %OTAOperation{
      id: ota_operation_id,
      base_image_url: base_image.url,
      device_id: device.id
    })
    |> Multi.run(:send_ota_request, fn _repo, _changes ->
      device_id = device.device_id

      with {:ok, client} <- Devices.appengine_client_from_device(device),
           :ok <-
             Astarte.send_ota_request_update(client, device_id, ota_operation_id, base_image.url) do
        {:ok, nil}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{ota_operation: ota_operation}} ->
        {:ok, Repo.preload(ota_operation, :device)}

      {:error, _failed_operation, failed_value, _changes_so_far} ->
        {:error, failed_value}
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

    with {:ok, %OTAOperation{id: id, status: status} = ota_operation} <- Repo.update(changeset) do
      Logger.info("OTA operation #{id} updated with status #{status}")

      if OTAOperation.final_state?(status) do
        cleanup_ephemeral_image(ota_operation)
      end

      {:ok, Repo.preload(ota_operation, :device)}
    end
  end

  # We only need to cleanup ephemeral images for manual OTA Operations
  defp cleanup_ephemeral_image(%OTAOperation{manual?: true} = ota_operation) do
    %OTAOperation{
      id: id,
      tenant_id: tenant_id,
      base_image_url: base_image_url
    } = ota_operation

    Logger.info("Cleaning up Ephemeral Image for OTA operation #{id}")

    # TODO: image cleanup is currently best effort
    _ = @ephemeral_image_module.delete(tenant_id, id, base_image_url)

    :ok
  end

  defp cleanup_ephemeral_image(_ota_operation) do
    :ok
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
    with {:ok, ota_operation} <- Repo.delete(ota_operation),
         :ok <- cleanup_ephemeral_image(ota_operation) do
      {:ok, Repo.preload(ota_operation, :device)}
    end
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
