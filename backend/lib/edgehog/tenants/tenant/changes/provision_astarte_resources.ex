#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.Tenants.Tenant.Changes.ProvisionAstarteResources do
  use Ash.Resource.Change

  alias Edgehog.Astarte

  @impl true
  def change(changeset, _opts, _ctx) do
    Ash.Changeset.after_action(changeset, &provision_astarte_resources/2)
  end

  defp provision_astarte_resources(changeset, tenant) do
    with {:ok, astarte_config} <- Ash.Changeset.fetch_argument(changeset, :astarte_config),
         {:ok, cluster} <- create_cluster(astarte_config),
         {:ok, realm} <- create_realm(tenant, cluster, astarte_config) do
      {:ok, %{tenant | realm: realm}}
    end
  end

  defp create_cluster(astarte_config) do
    case Astarte.create_cluster(%{base_api_url: astarte_config.base_api_url}) do
      {:ok, cluster} ->
        {:ok, cluster}

      {:error, ash_error} ->
        {:error, remap_cluster_error_fields(ash_error)}
    end
  end

  defp create_realm(tenant, cluster, astarte_config) do
    attrs = %{
      cluster_id: cluster.id,
      name: astarte_config.realm_name,
      private_key: astarte_config.realm_private_key
    }

    case Astarte.create_realm(attrs, tenant: tenant) do
      {:ok, realm} ->
        {:ok, realm}

      {:error, ash_error} ->
        {:error, remap_realm_error_fields(ash_error)}
    end
  end

  defp remap_cluster_error_fields(ash_error) do
    remapped_errors = Enum.map(ash_error.errors, &%{&1 | path: [:astarte_config]})

    %{ash_error | errors: remapped_errors}
  end

  defp remap_realm_error_fields(ash_error) do
    remapped_errors =
      Enum.map(ash_error.errors, fn
        %{field: :name} = error ->
          %{error | field: :realm_name, path: [:astarte_config]}

        %{field: :private_key} = error ->
          %{error | field: :realm_private_key, path: [:astarte_config]}

        error ->
          %{error | path: [:astarte_config]}
      end)

    %{ash_error | errors: remapped_errors}
  end
end
