# This file is part of Edgehog.
#
# Copyright 2024 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.AdminAPI.Tenants.TenantTest do
  use EdgehogWeb.AdminAPI.ConnCase

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte
  alias Edgehog.Tenants

  @valid_pem_public_key :secp256r1
                        |> X509.PrivateKey.new_ec()
                        |> X509.PublicKey.derive()
                        |> X509.PublicKey.to_pem()
                        |> String.trim()

  @valid_pem_private_key :secp256r1
                         |> X509.PrivateKey.new_ec()
                         |> X509.PrivateKey.to_pem()
                         |> String.trim()

  setup do
    stub(Edgehog.Tenants.ReconcilerMock, :reconcile_tenant, fn _tenant -> :ok end)
    stub(Edgehog.Containers.ReconcilerMock, :register_device, fn _device, _tenant -> :ok end)
    stub(Edgehog.Containers.ReconcilerMock, :stop_device, fn _device, _tenant -> :ok end)
    stub(Edgehog.Containers.ReconcilerMock, :start_link, fn _opts -> :ok end)
    {:ok, path: ~p"/admin-api/v1/tenants"}
  end

  describe "POST /admin-api/v1/tenants" do
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
        assert Enum.any?(
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

      assert length(errors) == 3

      expected_pointers = [
        "/data/attributes/astarte_config/base_api_url",
        "/data/attributes/astarte_config/realm_name",
        "/data/attributes/astarte_config/realm_private_key"
      ]

      received_pointers = Enum.map(errors, fn error -> error["source"]["pointer"] end)

      assert Enum.uniq(received_pointers) == Enum.uniq(expected_pointers)

      assert Enum.all?(errors, fn error ->
               error["status"] == "400" && error["title"] == "Required" &&
                 error["code"] == "required"
             end)
    end

    test "renders error for invalid astarte_config realm private key", %{conn: conn, path: path} do
      params = build_params(realm_private_key: "invalid")
      conn = post(conn, path, params)

      assert %{"errors" => [error]} = json_response(conn, 400)

      assert %{
               "code" => "invalid_attribute",
               "detail" => "is not a valid PEM private key",
               "source" => %{"pointer" => "/data/attributes/astarte_config/realm_private_key"},
               "status" => "400",
               "title" => "InvalidAttribute"
             } = error
    end

    test "renders error for invalid astarte_config realm name", %{conn: conn, path: path} do
      params = build_params(realm_name: "Invalid!")
      conn = post(conn, path, params)

      assert %{"errors" => [error]} = json_response(conn, 400)

      assert %{
               "code" => "invalid_attribute",
               "detail" => "should only contain" <> _,
               "source" => %{"pointer" => "/data/attributes/astarte_config/realm_name"},
               "status" => "400",
               "title" => "InvalidAttribute"
             } = error
    end

    test "renders error for invalid astarte_config cluster URL", %{conn: conn, path: path} do
      params = build_params(base_api_url: "invalid")
      conn = post(conn, path, params)

      assert %{"errors" => [error]} = json_response(conn, 400)

      assert %{
               "code" => "invalid_attribute",
               "detail" => "is not a valid URL",
               "source" => %{"pointer" => "/data/attributes/astarte_config/base_api_url"},
               "status" => "400",
               "title" => "InvalidAttribute"
             } = error
    end
  end

  describe "DELETE " do
    setup do
      tenant = tenant_fixture()

      %{tenant: tenant}
    end

    test "deletes a tenant with valid id", %{conn: conn, path: path, tenant: tenant} do
      path = path <> "/#{tenant.tenant_id}"
      conn = delete(conn, path, %{})

      assert %{"data" => %{"attributes" => tenant_attrs}} = json_response(conn, 200)

      assert tenant_attrs["name"] == tenant.name
      assert tenant_attrs["slug"] == tenant.slug
      assert tenant_attrs["default_locale"] == tenant.default_locale
      assert tenant_attrs["public_key"] == tenant.public_key
    end
  end

  defp build_params(opts) do
    %{
      data: %{
        type: "tenant",
        attributes: %{
          name: Keyword.get(opts, :tenant_name, unique_tenant_name()),
          slug: Keyword.get(opts, :tenant_slug, unique_tenant_slug()),
          public_key: Keyword.get(opts, :tenant_public_key, @valid_pem_public_key),
          default_locale: Keyword.get(opts, :tenant_default_locale, "it-IT"),
          astarte_config: %{
            base_api_url: Keyword.get(opts, :base_api_url, unique_cluster_base_api_url()),
            realm_name: Keyword.get(opts, :realm_name, unique_realm_name()),
            realm_private_key: Keyword.get(opts, :realm_private_key, @valid_pem_private_key)
          }
        }
      }
    }
  end
end
