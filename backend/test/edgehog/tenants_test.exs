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

  alias Edgehog.Tenants.Tenant

  import Edgehog.TenantsFixtures

  describe "Tenant.create/1" do
    @describetag :ported_to_ash

    test "with valid data creates a tenant" do
      public_key =
        X509.PrivateKey.new_ec(:secp256r1)
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()

      valid_attrs = %{name: "some name", slug: "some-name", public_key: public_key}

      assert {:ok, %Tenant{} = tenant} = Tenant.create(valid_attrs)
      assert tenant.name == "some name"
      assert tenant.slug == "some-name"
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
      assert_raise Ash.Error.Query.NotFound, fn -> Tenant.by_slug!(tenant.slug) end
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
