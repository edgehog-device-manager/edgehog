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

defmodule Edgehog.ProvisioningTest do
  # This can't be async: true because we're using Mox in global mode
  use Edgehog.DataCase
  use Edgehog.ReconcilerMockCase

  import Edgehog.AstarteFixtures
  import Edgehog.BaseImagesFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.OSManagementFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte
  alias Edgehog.Provisioning
  alias Edgehog.Provisioning.AstarteConfig
  alias Edgehog.Provisioning.TenantConfig
  alias Edgehog.Tenants

  @valid_pem_public_key X509.PrivateKey.new_ec(:secp256r1)
                        |> X509.PublicKey.derive()
                        |> X509.PublicKey.to_pem()

  @valid_pem_private_key X509.PrivateKey.new_ec(:secp256r1) |> X509.PrivateKey.to_pem()

  describe "provision_tenant/1" do
    test "with valid attrs creates the tenant, cluster and realm" do
      attrs = %{
        name: "Test",
        slug: "test",
        public_key: @valid_pem_public_key,
        astarte_config: %{
          base_api_url: "https://astarte.api.example",
          realm_name: "testrealm",
          realm_private_key: @valid_pem_private_key
        }
      }

      assert {:ok, %TenantConfig{} = tenant_config} = Provisioning.provision_tenant(attrs)

      %TenantConfig{
        name: name,
        slug: slug,
        public_key: public_key
      } = tenant_config

      assert name == attrs.name
      assert slug == attrs.slug
      assert public_key == attrs.public_key

      assert {:ok, tenant} = Tenants.fetch_tenant_by_slug(tenant_config.slug)

      assert %Tenants.Tenant{
               name: ^name,
               slug: ^slug,
               public_key: ^public_key
             } = tenant

      tenant_id = tenant.tenant_id

      %AstarteConfig{
        base_api_url: base_api_url,
        realm_name: realm_name,
        realm_private_key: realm_private_key
      } = tenant_config.astarte_config

      assert base_api_url == attrs.astarte_config.base_api_url
      assert realm_name == attrs.astarte_config.realm_name
      assert realm_private_key == attrs.astarte_config.realm_private_key

      assert Astarte.Cluster
             |> Ecto.Query.where(base_api_url: ^base_api_url)
             |> Repo.exists?(skip_tenant_id: true)

      assert {:ok, %Astarte.Realm{tenant_id: ^tenant_id, private_key: ^realm_private_key}} =
               Astarte.fetch_realm_by_name(realm_name)
    end

    test "succeeds when providing the URL of an already existing cluster" do
      cluster = cluster_fixture()

      assert {:ok, _tenant_config} =
               provision_tenant(astarte_config: [base_api_url: cluster.base_api_url])
    end

    test "triggers tenant reconciliation" do
      Edgehog.Tenants.ReconcilerMock
      |> expect(:reconcile_tenant, fn %Tenants.Tenant{} = tenant ->
        assert tenant.slug == "test"

        :ok
      end)

      assert {:ok, _tenant_config} = provision_tenant(slug: "test")
    end

    test "fails with invalid tenant slug" do
      assert {:error, changeset} = provision_tenant(slug: "1-INVALID")
      assert errors_on(changeset)[:slug] != nil
    end

    test "fails with invalid tenant public key" do
      assert {:error, changeset} = provision_tenant(public_key: "invalid")
      assert errors_on(changeset)[:public_key] != nil
    end

    test "fails with invalid Astarte base API url" do
      assert {:error, changeset} = provision_tenant(astarte_config: [base_api_url: "invalid"])
      assert errors_on(changeset)[:astarte_config][:base_api_url] != nil
    end

    test "fails with invalid Astarte realm name" do
      assert {:error, changeset} = provision_tenant(astarte_config: [realm_name: "INVALID"])
      assert errors_on(changeset)[:astarte_config][:realm_name] != nil
    end

    test "fails with invalid Astarte realm private key" do
      assert {:error, changeset} =
               provision_tenant(astarte_config: [realm_private_key: "invalid"])

      assert errors_on(changeset)[:astarte_config][:realm_private_key] != nil
    end

    test "fails when providing an already existing tenant slug" do
      tenant = tenant_fixture()

      assert {:error, changeset} = provision_tenant(slug: tenant.slug)
      assert "has already been taken" in errors_on(changeset)[:slug]
    end

    test "fails when providing an already existing tenant name" do
      tenant = tenant_fixture()

      assert {:error, changeset} = provision_tenant(name: tenant.name)
      assert "has already been taken" in errors_on(changeset)[:name]
    end

    test "fails when providing an already existing realm name" do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      assert {:error, changeset} =
               [astarte_config: [base_api_url: cluster.base_api_url, realm_name: realm.name]]
               |> provision_tenant()

      assert "has already been taken" in errors_on(changeset)[:astarte_config][:realm_name]
    end
  end

  describe "delete_tenant_by_slug/1" do
    test "returns {:error, :not_found} for unexisting tenant" do
      assert {:error, :not_found} = Provisioning.delete_tenant_by_slug("not_existing_slug")
    end

    test "deletes existing tenant", %{tenant: tenant} do
      assert {:ok, ^tenant} = Tenants.fetch_tenant_by_slug(tenant.slug)
      assert {:ok, _tenant} = Provisioning.delete_tenant_by_slug(tenant.slug)
      assert {:error, :not_found} = Tenants.fetch_tenant_by_slug(tenant.slug)
    end

    test "triggers tenant clean up", %{tenant: tenant} do
      cluster = cluster_fixture()
      _realm = realm_fixture(cluster)

      Edgehog.Tenants.ReconcilerMock
      |> expect(:cleanup_tenant, fn %Tenants.Tenant{} = cleanup_tenant ->
        assert cleanup_tenant.tenant_id == tenant.tenant_id

        :ok
      end)

      assert {:ok, _tenant} = Provisioning.delete_tenant_by_slug(tenant.slug)
    end

    test "cleans up base images", %{tenant: tenant} do
      base_images_count = Enum.random(2..10)
      for _ <- 1..base_images_count, do: base_image_fixture()

      test_pid = self()
      ref = make_ref()

      Edgehog.BaseImages.StorageMock
      |> expect(:delete, base_images_count, fn _base_image ->
        send(test_pid, {:base_image_deleted, ref})
        :ok
      end)

      assert {:ok, _tenant} = Provisioning.delete_tenant_by_slug(tenant.slug)

      1..base_images_count
      |> Enum.each(fn _ -> assert_receive {:base_image_deleted, ^ref} end)

      refute_receive {:base_image_deleted, ^ref}
    end

    test "ignores base image cleanup errors", %{tenant: tenant} do
      base_images_count = Enum.random(2..10)
      for _ <- 1..base_images_count, do: base_image_fixture()

      test_pid = self()
      ref = make_ref()

      Edgehog.BaseImages.StorageMock
      |> expect(:delete, base_images_count, fn _base_image ->
        send(test_pid, {:base_image_deletion_error, ref})
        {:error, :network_error}
      end)

      assert {:ok, _tenant} = Provisioning.delete_tenant_by_slug(tenant.slug)

      1..base_images_count
      |> Enum.each(fn _ -> assert_receive {:base_image_deletion_error, ^ref} end)

      refute_receive {:base_image_deletion_error, ^ref}
    end

    test "cleans up manual OTA operations", %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      manual_ota_operations_count = Enum.random(2..10)

      for _ <- 1..manual_ota_operations_count do
        device = device_fixture(realm)
        _ = manual_ota_operation_fixture(device)
      end

      test_pid = self()
      ref = make_ref()

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:delete, manual_ota_operations_count, fn _tenant_id, _ota_operation_id, _url ->
        send(test_pid, {:manual_ota_operation_deleted, ref})
        :ok
      end)

      assert {:ok, _tenant} = Provisioning.delete_tenant_by_slug(tenant.slug)

      1..manual_ota_operations_count
      |> Enum.each(fn _ -> assert_receive {:manual_ota_operation_deleted, ^ref} end)

      refute_receive {:manual_ota_operation_deleted, ^ref}
    end

    test "ignores manual ota operations cleanup errors", %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      manual_ota_operations_count = Enum.random(2..10)

      for _ <- 1..manual_ota_operations_count do
        device = device_fixture(realm)
        _ = manual_ota_operation_fixture(device)
      end

      test_pid = self()
      ref = make_ref()

      Edgehog.OSManagement.EphemeralImageMock
      |> expect(:delete, manual_ota_operations_count, fn _tenant_id, _ota_operation_id, _url ->
        send(test_pid, {:manual_ota_operation_deletion_error, ref})
        {:error, :network_error}
      end)

      assert {:ok, _tenant} = Provisioning.delete_tenant_by_slug(tenant.slug)

      1..manual_ota_operations_count
      |> Enum.each(fn _ -> assert_receive {:manual_ota_operation_deletion_error, ^ref} end)

      refute_receive {:manual_ota_operation_deletion_error, ^ref}
    end

    test "cleans up system model pictures", %{tenant: tenant} do
      system_models_count = Enum.random(2..10)

      for _ <- 1..system_models_count do
        picture_name =
          :crypto.strong_rand_bytes(10) |> Base.url_encode64(padding: false) |> String.downcase()

        picture_url = "https://domain.com/#{picture_name}.jpg"
        system_model_fixture(picture_url: picture_url)
      end

      test_pid = self()
      ref = make_ref()

      Edgehog.Assets.SystemModelPictureMock
      |> expect(:delete, system_models_count, fn _system_model, _picture_url ->
        send(test_pid, {:system_model_picture_deleted, ref})
        :ok
      end)

      assert {:ok, _tenant} = Provisioning.delete_tenant_by_slug(tenant.slug)

      1..system_models_count
      |> Enum.each(fn _ -> assert_receive {:system_model_picture_deleted, ^ref} end)

      refute_receive {:system_model_picture_deleted, ^ref}
    end

    test "ignores system model pictures cleanup errors", %{tenant: tenant} do
      system_models_count = Enum.random(2..10)

      for _ <- 1..system_models_count do
        picture_name =
          :crypto.strong_rand_bytes(10) |> Base.url_encode64(padding: false) |> String.downcase()

        picture_url = "https://domain.com/#{picture_name}.jpg"
        system_model_fixture(picture_url: picture_url)
      end

      test_pid = self()
      ref = make_ref()

      Edgehog.Assets.SystemModelPictureMock
      |> expect(:delete, system_models_count, fn _system_model, _picture_url ->
        send(test_pid, {:system_model_picture_deletion_error, ref})
        {:error, :network_error}
      end)

      assert {:ok, _tenant} = Provisioning.delete_tenant_by_slug(tenant.slug)

      1..system_models_count
      |> Enum.each(fn _ -> assert_receive {:system_model_picture_deletion_error, ^ref} end)

      refute_receive {:system_model_picture_deletion_error, ^ref}
    end
  end

  defp provision_tenant(opts) do
    {astarte_config, opts} = Keyword.pop(opts, :astarte_config, [])

    astarte_config =
      astarte_config
      |> Enum.into(%{
        base_api_url: unique_cluster_base_api_url(),
        realm_name: unique_realm_name(),
        realm_private_key: @valid_pem_private_key
      })

    attrs =
      opts
      |> Enum.into(%{
        name: unique_tenant_name(),
        slug: unique_tenant_slug(),
        public_key: @valid_pem_public_key,
        astarte_config: astarte_config
      })

    Provisioning.provision_tenant(attrs)
  end
end
