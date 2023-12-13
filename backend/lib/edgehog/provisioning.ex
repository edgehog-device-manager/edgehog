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

defmodule Edgehog.Provisioning do
  alias Edgehog.Astarte
  alias Edgehog.BaseImages
  alias Edgehog.OSManagement
  alias Edgehog.Provisioning.{AstarteConfig, TenantConfig, CleanupSupervisor}
  alias Edgehog.Repo
  alias Edgehog.Tenants

  def provision_tenant(attrs) do
    config_changeset = TenantConfig.changeset(%TenantConfig{}, attrs)

    with {:ok, tenant_config} <- Ecto.Changeset.apply_action(config_changeset, :create),
         {:error, error_changeset} <- provision_tenant_from_config(tenant_config) do
      {:error, remap_error_changeset(config_changeset, error_changeset)}
    end
  end

  def delete_tenant_by_slug(tenant_slug) do
    with {:ok, tenant} <- Tenants.fetch_tenant_by_slug(tenant_slug),
         tenant = Tenants.preload_astarte_resources_for_tenant(tenant),
         Repo.put_tenant_id(tenant.tenant_id),
         base_images = BaseImages.list_base_images(),
         ota_operations = OSManagement.list_ota_operations(),
         {:ok, deleted_tenant} <- Tenants.delete_tenant(tenant) do
      Tenants.cleanup_tenant(tenant)

      cleanup_base_images(base_images)
      cleanup_ota_operations(ota_operations)
      # TODO: clean up S3 storage (assets)

      {:ok, deleted_tenant}
    end
  end

  defp cleanup_base_images(base_images),
    do: start_cleanup_task(base_images, &BaseImages.cleanup_base_image/1)

  defp cleanup_ota_operations(ota_operations),
    do: start_cleanup_task(ota_operations, &OSManagement.cleanup_ephemeral_image/1)

  defp start_cleanup_task([], _cleanup_fun), do: :ok

  defp start_cleanup_task(list, cleanup_fun) when is_function(cleanup_fun, 1) do
    Task.Supervisor.start_child(CleanupSupervisor, fn ->
      CleanupSupervisor
      |> Task.Supervisor.async_stream_nolink(list, &cleanup_fun.(&1),
        ordered: false,
        on_timeout: :kill_task
      )
      |> Stream.run()
    end)
  end

  defp provision_tenant_from_config(tenant_config) do
    %TenantConfig{astarte_config: astarte_config} = tenant_config

    Repo.transact(fn ->
      with {:ok, tenant} <- create_tenant(tenant_config),
           Repo.put_tenant_id(tenant.tenant_id),
           {:ok, cluster} <- fetch_or_create_cluster(astarte_config),
           {:ok, realm} <- create_realm(cluster, astarte_config) do
        # Trigger immediate tenant reconciliation
        reconcile_tenant(tenant)

        # Build back the tenant config, to reflect what has actually been
        # saved in the database
        tenant_config = %TenantConfig{
          name: tenant.name,
          slug: tenant.slug,
          public_key: tenant.public_key,
          astarte_config: %AstarteConfig{
            base_api_url: cluster.base_api_url,
            realm_name: realm.name,
            realm_private_key: realm.private_key
          }
        }

        {:ok, tenant_config}
      end
    end)
  end

  defp create_tenant(tenant_config) do
    tenant_params = Map.take(tenant_config, [:name, :slug, :public_key])
    Tenants.create_tenant(tenant_params)
  end

  defp reconcile_tenant(tenant) do
    Tenants.preload_astarte_resources_for_tenant(tenant)
    |> Tenants.reconcile_tenant()
  end

  defp fetch_or_create_cluster(astarte_config) do
    Astarte.fetch_or_create_cluster(astarte_config.base_api_url)
  end

  defp create_realm(cluster, astarte_config) do
    realm_params = %{
      name: astarte_config.realm_name,
      private_key: astarte_config.realm_private_key
    }

    Astarte.create_realm(cluster, realm_params)
  end

  # Utils to remap error changesets from Cluster or Realm creation to a
  # TenantConfig error changest
  defp remap_error_changeset(config_changeset, error_changeset) do
    case error_changeset.data do
      %Tenants.Tenant{} ->
        # This has the same fields as TenantConfig, no need for remapping
        error_changeset

      %Astarte.Cluster{} ->
        field_mappings = %{base_api_url: :base_api_url}
        remap_astarte_config_errors(config_changeset, error_changeset, field_mappings)

      %Astarte.Realm{} ->
        field_mappings = %{name: :realm_name, private_key: :realm_private_key}
        remap_astarte_config_errors(config_changeset, error_changeset, field_mappings)
    end
  end

  defp remap_astarte_config_errors(config_changeset, error_changeset, field_mappings) do
    Enum.reduce(field_mappings, config_changeset, fn {source_field, dest_field}, acc ->
      if errors = error_changeset.errors[source_field] do
        put_in(acc.changes.astarte_config.errors[dest_field], errors)
        |> Map.put(:valid?, false)
      else
        acc
      end
    end)
  end
end
