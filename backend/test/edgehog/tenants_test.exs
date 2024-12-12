#
# This file is part of Edgehog.
#
# Copyright 2021-2025 SECO Mind Srl
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

defmodule Edgehog.TenantsTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Ash.Error.Changes.Required
  alias Ash.Error.Invalid
  alias Ash.Error.Query.NotFound
  alias Edgehog.Astarte
  alias Edgehog.BaseImages.StorageMock
  alias Edgehog.OSManagement.EphemeralImageMock
  alias Edgehog.Tenants
  alias Edgehog.Tenants.ReconcilerMock
  alias Edgehog.Tenants.Tenant

  require Ash.Query

  @valid_pem_public_key :secp256r1
                        |> X509.PrivateKey.new_ec()
                        |> X509.PublicKey.derive()
                        |> X509.PublicKey.to_pem()
                        |> String.trim()

  @valid_pem_private_key :secp256r1
                         |> X509.PrivateKey.new_ec()
                         |> X509.PrivateKey.to_pem()
                         |> String.trim()

  describe "Tenants.create_tenant/1" do
    test "with valid data creates a tenant" do
      name = unique_tenant_name()
      slug = unique_tenant_slug()
      public_key = @valid_pem_public_key
      default_locale = "it-IT"

      attrs = %{name: name, slug: slug, public_key: public_key, default_locale: default_locale}

      assert {:ok, tenant} = Tenants.create_tenant(attrs)

      assert %Tenant{
               name: ^name,
               slug: ^slug,
               public_key: ^public_key,
               default_locale: ^default_locale
             } = tenant
    end

    test "without default locale assigns 'en-US' as default one" do
      attrs = %{
        name: unique_tenant_name(),
        slug: unique_tenant_slug(),
        public_key: @valid_pem_public_key
      }

      assert {:ok, %Tenant{} = tenant} = Tenants.create_tenant(attrs)
      assert tenant.default_locale == "en-US"
    end

    test "with empty name returns error" do
      assert {:error, %Invalid{errors: [error]}} = create_tenant(name: nil)

      assert %Required{field: :name} = error
    end

    test "with non-unique name returns error" do
      _ = tenant_fixture(name: "foobar")
      assert {:error, %Invalid{errors: [error]}} = create_tenant(name: "foobar")

      assert %{field: :name, message: "has already been taken"} = error
    end

    test "with empty slug returns error" do
      assert {:error, %Invalid{errors: [error]}} = create_tenant(slug: nil)

      assert %Required{field: :slug} = error
    end

    test "with invalid slug returns error" do
      assert {:error, %Invalid{errors: [error]}} = create_tenant(slug: "Invalid Slug")

      error_msg = "should only contain lower case ASCII letters (from a to z), digits and -"
      assert %{field: :slug, message: ^error_msg} = error
    end

    test "with non-unique slug returns error" do
      _ = tenant_fixture(slug: "foobar")

      assert {:error, %Invalid{errors: [error]}} = create_tenant(slug: "foobar")

      assert %{field: :slug, message: "has already been taken"} = error
    end

    test "with invalid default locale returns error" do
      assert {:error, %Invalid{errors: [error]} = _changeset} =
               create_tenant(default_locale: "not_a_locale")

      assert %{field: :default_locale, message: "is not a valid locale"} = error
    end

    test "with empty public key returns error" do
      assert {:error, %Invalid{errors: [error]}} = create_tenant(public_key: nil)

      assert %Required{field: :public_key} = error
    end

    test "with invalid public key returns error" do
      assert {:error, %Invalid{errors: [error]}} =
               create_tenant(public_key: "not_a_public_key")

      assert %{field: :public_key, message: "is not a valid PEM public key"} = error
    end
  end

  describe "Tenants.reconcile_tenant/1" do
    test "triggers tenant reconciliation" do
      fixture = tenant_fixture()

      expect(ReconcilerMock, :reconcile_tenant, fn %Tenant{} = tenant ->
        assert tenant.slug == fixture.slug

        :ok
      end)

      assert :ok = Tenants.reconcile_tenant!(fixture)
    end
  end

  describe "Tenants.provision_tenant/1" do
    setup do
      stub(ReconcilerMock, :reconcile_tenant, fn _tenant -> :ok end)
      :ok
    end

    test "with valid attrs creates the tenant, cluster and realm" do
      tenant_name = unique_tenant_name()
      tenant_slug = unique_tenant_slug()
      tenant_public_key = @valid_pem_public_key
      tenant_default_locale = "it-IT"
      cluster_base_api_url = unique_cluster_base_api_url()
      realm_name = unique_realm_name()
      realm_private_key = @valid_pem_private_key

      attrs = %{
        name: tenant_name,
        slug: tenant_slug,
        public_key: tenant_public_key,
        default_locale: tenant_default_locale,
        astarte_config: %{
          base_api_url: cluster_base_api_url,
          realm_name: realm_name,
          realm_private_key: realm_private_key
        }
      }

      assert {:ok, tenant} = Tenants.provision_tenant(attrs)

      assert %Tenant{
               name: ^tenant_name,
               slug: ^tenant_slug,
               public_key: ^tenant_public_key,
               default_locale: ^tenant_default_locale
             } = tenant

      tenant = Ash.load!(tenant, [realm: [:cluster]], tenant: tenant)

      assert tenant.realm.cluster.base_api_url == attrs.astarte_config.base_api_url
      assert tenant.realm.name == attrs.astarte_config.realm_name
      assert tenant.realm.private_key == attrs.astarte_config.realm_private_key
    end

    test "without default locale provisions 'en-US' as default one" do
      attrs = %{
        name: unique_tenant_name(),
        slug: unique_tenant_slug(),
        public_key: @valid_pem_public_key,
        astarte_config: %{
          base_api_url: unique_cluster_base_api_url(),
          realm_name: unique_realm_name(),
          realm_private_key: @valid_pem_private_key
        }
      }

      assert {:ok, %Tenant{} = tenant} = Tenants.provision_tenant(attrs)
      assert tenant.default_locale == "en-US"
    end

    test "succeeds when providing the URL of an already existing cluster" do
      cluster = cluster_fixture()

      assert {:ok, _tenant} =
               provision_tenant(astarte_config: [base_api_url: cluster.base_api_url])
    end

    test "triggers tenant reconciliation" do
      expect(ReconcilerMock, :reconcile_tenant, fn %Tenant{} = tenant ->
        assert tenant.slug == "test"

        :ok
      end)

      assert {:ok, _tenant} = provision_tenant(slug: "test")
    end

    test "fails with invalid tenant slug" do
      assert {:error, %Invalid{errors: [error]}} = provision_tenant(slug: "1-INVALID")
      assert %{field: :slug} = error
    end

    test "fails with invalid tenant public key" do
      assert {:error, %Invalid{errors: [error]}} =
               provision_tenant(public_key: "invalid")

      assert %{field: :public_key} = error
    end

    test "fails with invalid Astarte base API url" do
      assert {:error, %Invalid{errors: [error]}} =
               provision_tenant(astarte_config: [base_api_url: "invalid"])

      assert %{field: :base_api_url, path: [:astarte_config]} = error
    end

    test "fails with invalid Astarte realm name" do
      assert {:error, %Invalid{errors: [error]}} =
               provision_tenant(astarte_config: [realm_name: "INVALID"])

      assert %{field: :realm_name, path: [:astarte_config]} = error
    end

    test "fails with invalid Astarte realm private key" do
      assert {:error, %Invalid{errors: [error]}} =
               provision_tenant(astarte_config: [realm_private_key: "invalid"])

      assert %{field: :realm_private_key, path: [:astarte_config]} = error
    end

    test "fails when providing an already existing tenant slug" do
      tenant = tenant_fixture()

      assert {:error, %Invalid{errors: [error]}} = provision_tenant(slug: tenant.slug)
      assert %{field: :slug} = error
    end

    test "fails when providing an already existing tenant name" do
      tenant = tenant_fixture()

      assert {:error, %Invalid{errors: [error]}} = provision_tenant(name: tenant.name)
      assert %{field: :name} = error
    end

    test "fails when providing an already existing realm name" do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id)

      assert {:error, %Invalid{errors: [error]}} =
               provision_tenant(astarte_config: [base_api_url: cluster.base_api_url, realm_name: realm.name])

      # TODO: this should be
      # assert %{field: :realm_name, path: [:astarte_config]} = error
      # but it currently doesn't work
      assert %{field: :name} = error
    end
  end

  describe "Tenants.destroy_tenant/1" do
    import Edgehog.AstarteFixtures
    import Edgehog.BaseImagesFixtures
    import Edgehog.DevicesFixtures
    import Edgehog.GroupsFixtures
    import Edgehog.OSManagementFixtures
    import Edgehog.UpdateCampaignsFixtures

    alias Edgehog.Astarte

    setup do
      %{tenant: tenant_fixture()}
    end

    test "deletes the tenant", %{tenant: tenant} do
      assert :ok = Tenants.destroy_tenant(tenant)
      assert_raise NotFound, fn -> Tenants.fetch_tenant_by_slug!(tenant.slug) end
    end

    test "cascading deletes associated realm", %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)

      assert :ok = Tenants.destroy_tenant(tenant)

      {:error, %NotFound{}} =
        Astarte.fetch_realm_by_name(realm.name, tenant: tenant)
    end

    test "cascading deletes referencing entities", %{tenant: tenant} do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)

      hardware_type = hardware_type_fixture(tenant: tenant)
      system_model = system_model_fixture(tenant: tenant)
      device = device_fixture(realm_id: realm.id, tenant: tenant)

      base_image_collection = base_image_collection_fixture(tenant: tenant)
      base_image = base_image_fixture(tenant: tenant)

      device_group = device_group_fixture(tenant: tenant)

      manual_ota_operation = manual_ota_operation_fixture(device_id: device.id, tenant: tenant)

      update_channel = update_channel_fixture(tenant: tenant)
      update_campaign = update_campaign_fixture(base_image_id: base_image.id, tenant: tenant)
      update_target = target_fixture(base_image_id: base_image.id, tenant: tenant)

      expect(StorageMock, :delete, fn to_delete ->
        assert to_delete.id == base_image.id
        :ok
      end)

      expect(EphemeralImageMock, :delete, fn tenant_id, ota_operation_id, url ->
        assert tenant_id == manual_ota_operation.tenant_id
        assert ota_operation_id == manual_ota_operation.id
        assert url == manual_ota_operation.base_image_url

        :ok
      end)

      assert :ok = Tenants.destroy_tenant(tenant)

      refute entry_exists?(Edgehog.Devices.HardwareType, hardware_type.id, tenant)
      refute entry_exists?(Edgehog.Devices.SystemModel, system_model.id, tenant)
      refute entry_exists?(Edgehog.Devices.Device, device.id, tenant)

      refute entry_exists?(
               Edgehog.BaseImages.BaseImageCollection,
               base_image_collection.id,
               tenant
             )

      refute entry_exists?(Edgehog.BaseImages.BaseImage, base_image.id, tenant)

      refute entry_exists?(Edgehog.Groups.DeviceGroup, device_group.id, tenant)

      refute entry_exists?(Edgehog.OSManagement.OTAOperation, manual_ota_operation.id, tenant)

      refute entry_exists?(Edgehog.UpdateCampaigns.UpdateChannel, update_channel.id, tenant)
      refute entry_exists?(Edgehog.UpdateCampaigns.UpdateCampaign, update_campaign.id, tenant)
      refute entry_exists?(Edgehog.UpdateCampaigns.UpdateTarget, update_target.id, tenant)
    end
  end

  defp provision_tenant(opts) do
    {astarte_config, opts} = Keyword.pop(opts, :astarte_config, [])

    astarte_config =
      Enum.into(astarte_config, %{
        base_api_url: unique_cluster_base_api_url(),
        realm_name: unique_realm_name(),
        realm_private_key: @valid_pem_private_key
      })

    attrs =
      Enum.into(opts, %{
        name: unique_tenant_name(),
        slug: unique_tenant_slug(),
        public_key: @valid_pem_public_key,
        astarte_config: astarte_config
      })

    Tenants.provision_tenant(attrs)
  end

  defp create_tenant(opts) do
    {public_key, opts} =
      Keyword.pop_lazy(opts, :public_key, fn ->
        :secp256r1
        |> X509.PrivateKey.new_ec()
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()
      end)

    opts
    |> Enum.into(%{
      name: unique_tenant_name(),
      slug: unique_tenant_slug(),
      public_key: public_key
    })
    |> Tenants.create_tenant()
  end

  defp entry_exists?(resource, id, tenant) do
    resource
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.set_tenant(tenant)
    |> Ash.exists?()
  end
end
