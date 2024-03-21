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

defmodule EdgehogWeb.AdminAPI.TenantsControllerTest do
  use EdgehogWeb.AdminAPI.ConnCase, async: true
  use Edgehog.ReconcilerMockCase

  import Ecto.Query, only: [where: 2]
  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte
  alias Edgehog.Repo
  alias Edgehog.Tenants

  @valid_pem_public_key X509.PrivateKey.new_ec(:secp256r1)
                        |> X509.PublicKey.derive()
                        |> X509.PublicKey.to_pem()

  @valid_pem_private_key X509.PrivateKey.new_ec(:secp256r1) |> X509.PrivateKey.to_pem()

  describe "POST /admin-api/v1/tenants" do
    setup %{conn: conn} do
      path = Routes.tenants_path(conn, :create)

      {:ok, path: path}
    end

    test "creates tenant with valid data", %{conn: conn, path: path} do
      tenant_name = unique_tenant_name()
      tenant_slug = unique_tenant_slug()
      tenant_public_key = @valid_pem_public_key
      cluster_base_api_url = unique_cluster_base_api_url()
      realm_name = unique_realm_name()
      realm_private_key = @valid_pem_private_key

      tenant_config = %{
        name: tenant_name,
        slug: tenant_slug,
        public_key: tenant_public_key,
        astarte_config: %{
          base_api_url: cluster_base_api_url,
          realm_name: realm_name,
          realm_private_key: @valid_pem_private_key
        }
      }

      conn = post(conn, path, tenant_config)

      assert response(conn, :created)

      assert {:ok, tenant} = Tenants.fetch_tenant_by_slug(tenant_slug)

      assert %Tenants.Tenant{
               name: ^tenant_name,
               slug: ^tenant_slug,
               public_key: ^tenant_public_key
             } = tenant

      Repo.put_tenant_id(tenant.tenant_id)

      assert {:ok, realm} = Astarte.fetch_realm_by_name(realm_name)

      assert %Astarte.Realm{
               name: ^realm_name,
               private_key: ^realm_private_key
             } = realm

      assert Astarte.Cluster
             |> where(base_api_url: ^cluster_base_api_url)
             |> Repo.exists?(skip_tenant_id: true)
    end

    test "render errors for invalid tenant data", %{conn: conn, path: path} do
      conn = post(conn, path, %{})

      body = json_response(conn, 422)

      required_data = ["name", "slug", "public_key", "astarte_config"]

      for path <- required_data do
        assert "can't be blank" in body["errors"][path]
      end
    end

    test "render errors for invalid astarte_config data", %{conn: conn, path: path} do
      conn =
        post(conn, path, %{
          name: unique_tenant_name(),
          slug: unique_tenant_slug(),
          public_key: @valid_pem_public_key,
          astarte_config: %{}
        })

      body = json_response(conn, 422)

      required_data = ["base_api_url", "realm_name", "realm_private_key"]

      for path <- required_data do
        assert "can't be blank" in body["errors"]["astarte_config"][path]
      end
    end
  end

  describe "DELETE /admin-api/v1/tenants/:tenant_slug" do
    test "deletes tenant with valid slug", %{conn: conn} do
      tenant = tenant_fixture()
      path = Routes.tenants_path(conn, :delete_by_slug, tenant.slug)

      conn = delete(conn, path)

      assert response(conn, :no_content)

      assert assert {:error, :not_found} = Tenants.fetch_tenant_by_slug(tenant.slug)
    end

    test "returns error for invalid tenant slug", %{conn: conn} do
      path = Routes.tenants_path(conn, :delete_by_slug, "not_existing_slug")

      conn = delete(conn, path)

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
