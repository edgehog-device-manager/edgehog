#
# This file is part of Edgehog.
#
# Copyright 2023-2026 SECO Mind Srl
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

defmodule EdgehogWeb.AdminAPI.AuthTest do
  # This can't be async: true since it modifies the Application env
  use EdgehogWeb.AdminAPI.ConnCase, async: false

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Tenants.ReconcilerMock

  @valid_pem_public_key :secp256r1
                        |> X509.PrivateKey.new_ec()
                        |> X509.PublicKey.derive()
                        |> X509.PublicKey.to_pem()
                        |> String.trim()

  @valid_pem_private_key :secp256r1
                         |> X509.PrivateKey.new_ec()
                         |> X509.PrivateKey.to_pem()
                         |> String.trim()

  @valid_tenant_config %{
    data: %{
      type: "tenant",
      attributes: %{
        name: unique_tenant_name(),
        slug: unique_tenant_slug(),
        public_key: @valid_pem_public_key,
        astarte_config: %{
          base_api_url: unique_cluster_base_api_url(),
          realm_name: unique_realm_name(),
          realm_private_key: @valid_pem_private_key
        }
      }
    }
  }

  setup do
    stub(Edgehog.Containers.ReconcilerMock, :register_device, fn _device, _tenant -> :ok end)
    stub(Edgehog.Containers.ReconcilerMock, :stop_device, fn _device, _tenant -> :ok end)
    stub(Edgehog.Containers.ReconcilerMock, :start_link, fn _opts -> :ok end)
    {:ok, path: ~p"/admin-api/v1/tenants"}
  end

  describe "unconfigured Admin authentication" do
    @describetag :unconfigured

    test "returns 401 for request without JWT", %{
      conn: conn,
      path: path
    } do
      conn = post(conn, path, @valid_tenant_config)

      assert %{"errors" => %{"detail" => "Unauthorized"}} = json_response(conn, 401)
    end

    test "returns 403 for request with JWT", %{
      conn: conn,
      path: path
    } do
      other_private_key = X509.PrivateKey.new_ec(:secp256r1)

      conn =
        conn
        |> authenticate_connection(other_private_key)
        |> post(path, @valid_tenant_config)

      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end
  end

  describe "configured Admin authentication" do
    @describetag :unauthenticated

    test "unauthenticated request returns 401", %{conn: conn, path: path} do
      conn = post(conn, path)

      assert %{"errors" => %{"detail" => "Unauthorized"}} = json_response(conn, 401)
    end

    test "request with JWT signed with another private key returns 403", %{
      conn: conn,
      path: path
    } do
      other_private_key = X509.PrivateKey.new_ec(:secp256r1)

      conn =
        conn
        |> authenticate_connection(other_private_key)
        |> post(path)

      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    test "request with JWT but without e_ara claim returns 403", %{
      conn: conn,
      path: path,
      admin_private_key: admin_private_key
    } do
      conn =
        conn
        |> authenticate_connection(admin_private_key, %{other: "*"})
        |> post(path)

      assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
    end

    test "request with JWT with correct signature and claims returns 201", %{
      conn: conn,
      path: path,
      admin_private_key: admin_private_key
    } do
      stub(ReconcilerMock, :reconcile_tenant, fn _tenant -> :ok end)

      conn =
        conn
        |> authenticate_connection(admin_private_key, %{e_ara: "*"})
        |> post(path, @valid_tenant_config)

      assert response(conn, :created)
    end
  end
end
