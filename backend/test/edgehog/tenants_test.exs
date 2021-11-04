#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind
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

defmodule Edgehog.TenantsTest do
  use Edgehog.DataCase
  @moduletag :no_tenant_fixtures

  alias Edgehog.Tenants

  describe "tenants" do
    alias Edgehog.Tenants.Tenant

    import Edgehog.TenantsFixtures

    @invalid_attrs %{name: nil}

    test "list_tenants/0 returns all tenants" do
      tenant = tenant_fixture()
      assert Tenants.list_tenants() == [tenant]
    end

    test "get_tenant!/1 returns the tenant with given id" do
      tenant = tenant_fixture()
      assert Tenants.get_tenant!(tenant.tenant_id) == tenant
    end

    test "create_tenant/1 with valid data creates a tenant" do
      valid_attrs = %{name: "some name"}

      assert {:ok, %Tenant{} = tenant} = Tenants.create_tenant(valid_attrs)
      assert tenant.name == "some name"
    end

    test "create_tenant/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tenants.create_tenant(@invalid_attrs)
    end

    test "update_tenant/2 with valid data updates the tenant" do
      tenant = tenant_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Tenant{} = tenant} = Tenants.update_tenant(tenant, update_attrs)
      assert tenant.name == "some updated name"
    end

    test "update_tenant/2 with invalid data returns error changeset" do
      tenant = tenant_fixture()
      assert {:error, %Ecto.Changeset{}} = Tenants.update_tenant(tenant, @invalid_attrs)
      assert tenant == Tenants.get_tenant!(tenant.tenant_id)
    end

    test "delete_tenant/1 deletes the tenant" do
      tenant = tenant_fixture()
      assert {:ok, %Tenant{}} = Tenants.delete_tenant(tenant)
      assert_raise Ecto.NoResultsError, fn -> Tenants.get_tenant!(tenant.tenant_id) end
    end

    test "change_tenant/1 returns a tenant changeset" do
      tenant = tenant_fixture()
      assert %Ecto.Changeset{} = Tenants.change_tenant(tenant)
    end
  end
end
