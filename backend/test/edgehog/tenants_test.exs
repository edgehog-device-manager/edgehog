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

defmodule Edgehog.TenantsTest do
  use Edgehog.DataCase, async: true

  alias Edgehog.Tenants
  alias Edgehog.Tenants.Tenant

  import Edgehog.TenantsFixtures

  test "list_tenants/0 returns all tenants" do
    tenant = tenant_fixture()
    assert Tenants.list_tenants() == [tenant]
  end

  test "get_tenant!/1 returns the tenant with given id" do
    tenant = tenant_fixture()
    assert Tenants.get_tenant!(tenant.tenant_id) == tenant
  end

  describe "create_tenant/1" do
    test "with valid data creates a tenant" do
      public_key =
        X509.PrivateKey.new_ec(:secp256r1)
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()

      valid_attrs = %{name: "some name", slug: "some-name", public_key: public_key}

      assert {:ok, %Tenant{} = tenant} = Tenants.create_tenant(valid_attrs)
      assert tenant.name == "some name"
      assert tenant.slug == "some-name"
      assert tenant.default_locale == "en-US"
    end

    test "with empty name returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = create_tenant(name: nil)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "with non-unique name returns error changeset" do
      _ = tenant_fixture(name: "foobar")

      assert {:error, %Ecto.Changeset{} = changeset} = create_tenant(name: "foobar")

      assert "has already been taken" in errors_on(changeset).name
    end

    test "with empty slug returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = create_tenant(slug: nil)

      assert "can't be blank" in errors_on(changeset).slug
    end

    test "with invalid slug returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = create_tenant(slug: "Invalid Slug")

      error_msg = "should only contain lower case ASCII letters (from a to z), digits and -"
      assert error_msg in errors_on(changeset).slug
    end

    test "with non-unique slug returns error changeset" do
      _ = tenant_fixture(slug: "foobar")

      assert {:error, %Ecto.Changeset{} = changeset} = create_tenant(slug: "foobar")

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "with invalid default locale returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_tenant(default_locale: "not_a_locale")

      assert "is not a valid locale" in errors_on(changeset).default_locale
    end

    test "with empty public key returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} = create_tenant(public_key: nil)

      assert "can't be blank" in errors_on(changeset).public_key
    end

    test "with invalid public key returns error changeset" do
      assert {:error, %Ecto.Changeset{} = changeset} =
               create_tenant(public_key: "not_a_public_key")

      assert "is not a valid PEM public key" in errors_on(changeset).public_key
    end
  end

  describe "update_tenant/2" do
    setup do
      {:ok, tenant: tenant_fixture()}
    end

    test "with valid data updates the tenant", %{tenant: tenant} do
      attrs = %{
        name: "some updated name",
        slug: "some-updated-name",
        default_locale: "it-IT"
      }

      assert {:ok, %Tenant{} = tenant} = Tenants.update_tenant(tenant, attrs)
      assert tenant.name == "some updated name"
      assert tenant.slug == "some-updated-name"
      assert tenant.default_locale == "it-IT"
    end

    test "with empty name returns error changeset", %{tenant: tenant} do
      assert {:error, %Ecto.Changeset{} = changeset} = update_tenant(tenant, name: nil)

      assert "can't be blank" in errors_on(changeset).name
    end

    test "with non-unique name returns error changeset", %{tenant: tenant} do
      _ = tenant_fixture(name: "foobar")

      assert {:error, %Ecto.Changeset{} = changeset} = update_tenant(tenant, name: "foobar")

      assert "has already been taken" in errors_on(changeset).name
    end

    test "with empty slug returns error changeset", %{tenant: tenant} do
      assert {:error, %Ecto.Changeset{} = changeset} = update_tenant(tenant, slug: nil)

      assert "can't be blank" in errors_on(changeset).slug
    end

    test "with invalid slug returns error changeset", %{tenant: tenant} do
      assert {:error, %Ecto.Changeset{} = changeset} = update_tenant(tenant, slug: "Invalid Slug")

      error_msg = "should only contain lower case ASCII letters (from a to z), digits and -"
      assert error_msg in errors_on(changeset).slug
    end

    test "with non-unique slug returns error changeset", %{tenant: tenant} do
      _ = tenant_fixture(slug: "foobar")

      assert {:error, %Ecto.Changeset{} = changeset} = update_tenant(tenant, slug: "foobar")

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "with invalid default locale returns error changeset", %{tenant: tenant} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_tenant(tenant, default_locale: "not_a_locale")

      assert "is not a valid locale" in errors_on(changeset).default_locale
    end

    test "with empty public key returns error changeset", %{tenant: tenant} do
      assert {:error, %Ecto.Changeset{} = changeset} = update_tenant(tenant, public_key: nil)

      assert "can't be blank" in errors_on(changeset).public_key
    end

    test "with invalid public key returns error changeset", %{tenant: tenant} do
      assert {:error, %Ecto.Changeset{} = changeset} =
               update_tenant(tenant, public_key: "not_a_public_key")

      assert "is not a valid PEM public key" in errors_on(changeset).public_key
    end
  end

  describe "delete_tenant/1" do
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
      assert {:ok, %Tenant{}} = Tenants.delete_tenant(tenant)
      assert_raise Ecto.NoResultsError, fn -> Tenants.get_tenant!(tenant.tenant_id) end
    end

    test "cascading deletes associated realm", %{tenant: tenant} do
      Edgehog.Repo.put_tenant_id(tenant.tenant_id)
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      assert {:ok, ^realm} = Astarte.fetch_realm_by_name(realm.name)
      assert {:ok, %Tenant{}} = Tenants.delete_tenant(tenant)
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

      assert {:ok, %Tenant{}} = Tenants.delete_tenant(tenant)

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

  test "change_tenant/1 returns a tenant changeset" do
    tenant = tenant_fixture()
    assert %Ecto.Changeset{} = Tenants.change_tenant(tenant)
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
    |> Tenants.create_tenant()
  end

  defp update_tenant(tenant, opts) do
    attrs = Enum.into(opts, %{})

    Tenants.update_tenant(tenant, attrs)
  end

  defp entry_exists?(schema, id) do
    schema
    |> Ecto.Query.where(id: ^id)
    |> Repo.exists?(skip_tenant_id: true)
  end
end
