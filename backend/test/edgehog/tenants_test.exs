#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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
  use Edgehog.ReconcilerMockCase

  alias Edgehog.Astarte
  alias Edgehog.Tenants
  alias Edgehog.Tenants.AstarteConfig
  alias Edgehog.Tenants.Tenant

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  require Ash.Query

  @valid_pem_public_key X509.PrivateKey.new_ec(:secp256r1)
                        |> X509.PublicKey.derive()
                        |> X509.PublicKey.to_pem()
                        |> String.trim()

  @valid_pem_private_key X509.PrivateKey.new_ec(:secp256r1)
                         |> X509.PrivateKey.to_pem()
                         |> String.trim()

  describe "Tenant.create/1" do
    @describetag :ported_to_ash

    test "with valid data creates a tenant" do
      name = unique_tenant_name()
      slug = unique_tenant_slug()
      public_key = @valid_pem_public_key
      default_locale = "it-IT"

      attrs = %{name: name, slug: slug, public_key: public_key, default_locale: default_locale}

      assert {:ok, tenant} = Tenant.create(attrs)

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

      assert {:ok, %Tenant{} = tenant} = Tenant.create(attrs)
      assert tenant.default_locale == "en-US"
    end

    test "with empty name returns error" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} = create_tenant(name: nil)

      assert %Ash.Error.Changes.Required{field: :name} = error
    end

    test "with non-unique name returns error" do
      _ = tenant_fixture(name: "foobar")
      assert {:error, %Ash.Error.Invalid{errors: [error]}} = create_tenant(name: "foobar")

      assert %{field: :name, message: "has already been taken"} = error
    end

    test "with empty slug returns error" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} = create_tenant(slug: nil)

      assert %Ash.Error.Changes.Required{field: :slug} = error
    end

    test "with invalid slug returns error" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} = create_tenant(slug: "Invalid Slug")

      error_msg = "should only contain lower case ASCII letters (from a to z), digits and -"
      assert %{field: :slug, message: ^error_msg} = error
    end

    test "with non-unique slug returns error" do
      _ = tenant_fixture(slug: "foobar")

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = create_tenant(slug: "foobar")

      assert %{field: :slug, message: "has already been taken"} = error
    end

    test "with invalid default locale returns error" do
      assert {:error, %Ash.Error.Invalid{errors: [error]} = changeset} =
               create_tenant(default_locale: "not_a_locale")

      assert %{field: :default_locale, message: "is not a valid locale"} = error
    end

    test "with empty public key returns error" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} = create_tenant(public_key: nil)

      assert %Ash.Error.Changes.Required{field: :public_key} = error
    end

    test "with invalid public key returns error" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               create_tenant(public_key: "not_a_public_key")

      assert %{field: :public_key, message: "is not a valid PEM public key"} = error
    end
  end

  describe "Tenant.reconcile/1" do
    test "triggers tenant reconciliation" do
      Edgehog.Tenants.ReconcilerMock
      |> expect(:reconcile_tenant, fn %Tenant{} = tenant ->
        assert tenant.slug == "test"

        :ok
      end)

      tenant = tenant_fixture()
      assert :ok = Tenant.reconcile!(tenant)
    end
  end

  describe "Tenant.provision/1" do
    @describetag :ported_to_ash

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

      assert {:ok, tenant} = Tenant.provision(attrs)

      assert %Tenant{
               name: ^tenant_name,
               slug: ^tenant_slug,
               public_key: ^tenant_public_key,
               default_locale: ^tenant_default_locale
             } = tenant

      tenant = Tenants.load!(tenant, realm: [:cluster])

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

      assert {:ok, %Tenant{} = tenant} = Tenant.provision(attrs)
      assert tenant.default_locale == "en-US"
    end

    test "succeeds when providing the URL of an already existing cluster" do
      cluster = cluster_fixture()

      assert {:ok, _tenant} =
               provision_tenant(astarte_config: [base_api_url: cluster.base_api_url])
    end

    test "triggers tenant reconciliation" do
      Edgehog.Tenants.ReconcilerMock
      |> expect(:reconcile_tenant, fn %Tenant{} = tenant ->
        assert tenant.slug == "test"

        :ok
      end)

      assert {:ok, _tenant} = provision_tenant(slug: "test")
    end

    test "fails with invalid tenant slug" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} = provision_tenant(slug: "1-INVALID")
      assert %{field: :slug} = error
    end

    test "fails with invalid tenant public key" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               provision_tenant(public_key: "invalid")

      assert %{field: :public_key} = error
    end

    test "fails with invalid Astarte base API url" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               provision_tenant(astarte_config: [base_api_url: "invalid"])

      assert %{field: :base_api_url, path: [:astarte_config]} = error
    end

    test "fails with invalid Astarte realm name" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               provision_tenant(astarte_config: [realm_name: "INVALID"])

      assert %{field: :realm_name, path: [:astarte_config]} = error
    end

    test "fails with invalid Astarte realm private key" do
      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               provision_tenant(astarte_config: [realm_private_key: "invalid"])

      assert %{field: :realm_private_key, path: [:astarte_config]} = error
    end

    test "fails when providing an already existing tenant slug" do
      tenant = tenant_fixture()

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = provision_tenant(slug: tenant.slug)
      assert %{field: :slug} = error
    end

    test "fails when providing an already existing tenant name" do
      tenant = tenant_fixture()

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = provision_tenant(name: tenant.name)
      assert %{field: :name} = error
    end

    test "fails when providing an already existing realm name" do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id)

      assert {:error, %Ash.Error.Invalid{errors: [error]}} =
               [astarte_config: [base_api_url: cluster.base_api_url, realm_name: realm.name]]
               |> provision_tenant()

      # TODO: this should be
      # assert %{field: :realm_name, path: [:astarte_config]} = error
      # but it currently doesn't work
      assert %{field: :name} = error
    end
  end

  describe "Tenant.destroy/1" do
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

    @tag :ported_to_ash
    test "deletes the tenant", %{tenant: tenant} do
      assert :ok = Tenant.destroy(tenant)
      assert_raise Ash.Error.Query.NotFound, fn -> Tenant.fetch_by_slug!(tenant.slug) end
    end

    test "cascading deletes associated realm", %{tenant: tenant} do
      Edgehog.Repo.put_tenant_id(tenant.tenant_id)
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      assert {:ok, ^realm} = Astarte.fetch_realm_by_name(realm.name)
      assert :ok = Tenant.destroy(tenant)
      {:error, :realm_not_found} = Astarte.fetch_realm_by_name(realm.name)
    end

    test "cascading deletes referencing entities", %{tenant: tenant} do
      Edgehog.Repo.put_tenant_id(tenant.tenant_id)
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      hardware_type = hardware_type_fixture()
      system_model = system_model_fixture()
      device = device_fixture(realm)

      base_image_collection = base_image_collection_fixture()
      base_image = base_image_fixture()

      device_group = device_group_fixture()

      manual_ota_operation = manual_ota_operation_fixture(device)

      update_channel = update_channel_fixture()
      update_campaign = update_campaign_fixture()
      update_target = target_fixture()

      assert :ok = Tenant.destroy(tenant)

      refute entry_exists?(Edgehog.Devices.HardwareType, hardware_type.id)
      refute entry_exists?(Edgehog.Devices.SystemModel, system_model.id)
      refute entry_exists?(Edgehog.Devices.Device, device.id)

      refute entry_exists?(Edgehog.BaseImages.BaseImageCollection, base_image_collection.id)
      refute entry_exists?(Edgehog.BaseImages.BaseImage, base_image.id)

      refute entry_exists?(Edgehog.Groups.DeviceGroup, device_group.id)

      refute entry_exists?(Edgehog.OSManagement.OTAOperation, manual_ota_operation.id)

      refute entry_exists?(Edgehog.UpdateCampaigns.UpdateChannel, update_channel.id)
      refute entry_exists?(Edgehog.UpdateCampaigns.UpdateCampaign, update_campaign.id)
      refute entry_exists?(Edgehog.UpdateCampaigns.Target, update_target.id)
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

    Tenant.provision(attrs)
  end

  defp create_tenant(opts) do
    {public_key, opts} =
      Keyword.pop_lazy(opts, :public_key, fn ->
        X509.PrivateKey.new_ec(:secp256r1)
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()
      end)

    opts
    |> Enum.into(%{
      name: unique_tenant_name(),
      slug: unique_tenant_slug(),
      public_key: public_key
    })
    |> Tenant.create()
  end

  defp entry_exists?(schema, id) do
    schema
    |> Ecto.Query.where(id: ^id)
    |> Repo.exists?(skip_tenant_id: true)
  end
end
