#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule EdgehogWeb.AdminAPI.Tenants.TenantTest do
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
                        |> String.trim()

  @valid_pem_private_key X509.PrivateKey.new_ec(:secp256r1)
                         |> X509.PrivateKey.to_pem()
                         |> String.trim()

  describe "POST /admin-api/v1/tenants" do
    setup do
      {:ok, path: ~p"/admin-api/v1/tenants"}
    end

    test "creates tenant with valid data", %{conn: conn, path: path} do
      tenant_name = unique_tenant_name()
      tenant_slug = unique_tenant_slug()
      tenant_public_key = @valid_pem_public_key
      tenant_default_locale = "it-IT"
      cluster_base_api_url = unique_cluster_base_api_url()
      realm_name = unique_realm_name()
      realm_private_key = @valid_pem_private_key

      params = %{
        data: %{
          type: "tenant",
          attributes: %{
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
        }
      }

      conn = post(conn, path, params)

      assert response(conn, :created)

      assert tenant = Tenants.fetch_tenant_by_slug!(tenant_slug)

      assert %Tenants.Tenant{
               name: ^tenant_name,
               slug: ^tenant_slug,
               public_key: ^tenant_public_key,
               default_locale: ^tenant_default_locale
             } = tenant

      tenant = Ash.load!(tenant, [realm: [:cluster]], tenant: tenant)

      assert %Astarte.Realm{
               name: ^realm_name,
               private_key: ^realm_private_key
             } = tenant.realm

      assert tenant.realm.cluster.base_api_url == cluster_base_api_url
    end

    test "without default locale assigns 'en-US' as default one", %{conn: conn, path: path} do
      tenant_slug = unique_tenant_slug()

      params = %{
        data: %{
          type: "tenant",
          attributes: %{
            name: unique_tenant_name(),
            slug: tenant_slug,
            public_key: @valid_pem_public_key,
            astarte_config: %{
              base_api_url: unique_cluster_base_api_url(),
              realm_name: unique_realm_name(),
              realm_private_key: @valid_pem_private_key
            }
          }
        }
      }

      conn = post(conn, path, params)

      assert response(conn, :created)

      assert tenant = Tenants.fetch_tenant_by_slug!(tenant_slug)

      assert tenant.default_locale == "en-US"
    end

    test "render errors for invalid tenant data", %{conn: conn, path: path} do
      params = %{data: %{type: "tenant"}}

      conn = post(conn, path, params)

      assert %{"errors" => errors} = json_response(conn, 400)

      required_data = ["name", "slug", "public_key", "astarte_config"]

      for required <- required_data do
        assert Enum.find(
                 errors,
                 &(&1["detail"] == "is required" and
                     &1["source"] == %{"pointer" => "/data/attributes/#{required}"})
               )
      end
    end

    test "render errors for invalid astarte_config data", %{conn: conn, path: path} do
      params = %{
        data: %{
          type: "tenant",
          attributes: %{
            name: unique_tenant_name(),
            slug: unique_tenant_slug(),
            public_key: @valid_pem_public_key,
            astarte_config: %{}
          }
        }
      }

      conn =
        post(conn, path, params)

      assert %{"errors" => errors} = json_response(conn, 400)

      required_data = ["base_api_url", "realm_name", "realm_private_key"]

      for required <- required_data do
        assert Enum.find(
                 errors,
                 &(&1["detail"] == "is required" and
                     &1["source"] == %{"pointer" => "/data/attributes/astarte_config/#{required}"})
               )
      end
    end
  end
end
