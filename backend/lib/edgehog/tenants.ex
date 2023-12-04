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

defmodule Edgehog.Tenants do
  @moduledoc """
  The Tenants context.
  """

  import Ecto.Query, warn: false
  alias Edgehog.Repo

  alias Edgehog.Tenants.Reconciler
  alias Edgehog.Tenants.Tenant

  @reconciler_module Application.compile_env(
                       :edgehog,
                       :reconciler_module,
                       Reconciler
                     )

  @doc """
  Returns the list of tenants.

  ## Examples

      iex> list_tenants()
      [%Tenant{}, ...]

  """
  def list_tenants do
    Repo.all(Tenant, skip_tenant_id: true)
  end

  @doc """
  Gets a single tenant.

  Raises `Ecto.NoResultsError` if the Tenant does not exist.

  ## Examples

      iex> get_tenant!(123)
      %Tenant{}

      iex> get_tenant!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tenant!(id), do: Repo.get!(Tenant, id, skip_tenant_id: true)

  @doc """
  Fetches a single tenant by its slug.

  Returns `{:ok, tenant}` or `{:error, :not_found}`.

  ## Examples

  iex> fetch_tenant_by_slug("test")
  {:ok, %Tenant{}}

  iex> fetch_tenant_by_slug("unknown")
  {:error, :not_found}

  """
  def fetch_tenant_by_slug(slug) do
    Repo.fetch_by(Tenant, [slug: slug], skip_tenant_id: true)
  end

  @doc """
  Creates a tenant.

  ## Examples

      iex> create_tenant(%{field: value})
      {:ok, %Tenant{}}

      iex> create_tenant(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tenant(attrs \\ %{}) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tenant.

  ## Examples

      iex> update_tenant(tenant, %{field: new_value})
      {:ok, %Tenant{}}

      iex> update_tenant(tenant, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tenant(%Tenant{} = tenant, attrs) do
    tenant
    |> Tenant.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tenant.

  ## Examples

      iex> delete_tenant(tenant)
      {:ok, %Tenant{}}

      iex> delete_tenant(tenant)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tenant(%Tenant{} = tenant) do
    Repo.delete(tenant)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tenant changes.

  ## Examples

      iex> change_tenant(tenant)
      %Ecto.Changeset{data: %Tenant{}}

  """
  def change_tenant(%Tenant{} = tenant, attrs \\ %{}) do
    Tenant.changeset(tenant, attrs)
  end

  @doc """
  Preloads the Astarte realm and its cluster for a Tenant.
  """
  def preload_astarte_resources_for_tenant(tenant_or_tenants) do
    Repo.preload(tenant_or_tenants, [realm: [:cluster]], skip_tenant_id: true)
  end

  def reconcile_tenant(%Tenant{} = tenant) do
    @reconciler_module.reconcile_tenant(tenant)
  end

  def cleanup_tenant(%Tenant{} = tenant) do
    @reconciler_module.cleanup_tenant(tenant)
  end

  @doc """
  Returns an `%Astarte.Client.RealmManagement{}` for the given tenant.

  The tenant must have the Astarte realm and cluster preloaded, call
  `preload_astarte_resources_for_tenant/1` before calling this function to make sure of this.

  ## Examples

  iex> realm_management_client_from_tenant(tenant)
  {:ok, %Astarte.Client.RealmManagement{}}

  iex> realm_management_client_from_tenant(tenant)
  {:error, :invalid_private_key}

  """
  def realm_management_client_from_tenant(%Tenant{realm: %{cluster: cluster} = realm})
      when is_struct(realm, Edgehog.Astarte.Realm) and is_struct(cluster, Edgehog.Astarte.Cluster) do
    %{
      name: realm_name,
      private_key: private_key
    } = realm

    %{base_api_url: base_api_url} = cluster

    Astarte.Client.RealmManagement.new(base_api_url, realm_name, private_key: private_key)
  end
end
