#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule EdgehogWeb.AuthTest do
  # This can't be async: true since it modifies the Application env
  use EdgehogWeb.ConnCase, async: false

  alias Edgehog.Config
  alias Edgehog.Containers.ReconcilerMock

  @query """
  {
    tenantInfo {
      name
    }
  }
  """

  setup do
    stub(ReconcilerMock, :register_device, fn _device, _tenant -> :ok end)
    stub(ReconcilerMock, :stop_device, fn _device, _tenant -> :ok end)
    stub(ReconcilerMock, :start_link, fn _opts -> :ok end)

    :ok
  end

  test "unauthenticated request returns 401", %{conn: conn, api_path: api_path} do
    conn = get(conn, api_path, query: @query)

    assert %{"errors" => %{"detail" => "Unauthorized"}} = json_response(conn, 401)
  end

  test "unauthenticated request with disabled authentication returns 200", %{
    conn: conn,
    api_path: api_path
  } do
    Config.put_disable_tenant_authentication(true)

    on_exit(fn ->
      # Cleanup at the end
      Config.reload_disable_tenant_authentication()
    end)

    conn = get(conn, api_path, query: @query)

    assert json_response(conn, 200)
  end

  test "request on unexisting tenant returns 403", %{conn: conn} do
    conn = get(conn, "/tenants/notexisting/api", query: @query)

    assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
  end

  test "request with JWT signed with another private key returns 403", %{
    conn: conn,
    api_path: api_path
  } do
    other_private_key = X509.PrivateKey.new_ec(:secp256r1)

    conn =
      conn
      |> authenticate_connection(other_private_key)
      |> get(api_path, query: @query)

    assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
  end

  test "request with JWT without e_tga claims returns 403", %{
    conn: conn,
    api_path: api_path,
    tenant_private_key: tenant_private_key
  } do
    conn =
      conn
      |> authenticate_connection(tenant_private_key, %{other: "claims"})
      |> get(api_path, query: @query)

    assert %{"errors" => %{"detail" => "Forbidden"}} = json_response(conn, 403)
  end

  test "request with JWT with correct signature and claims returns 200", %{
    conn: conn,
    api_path: api_path,
    tenant_private_key: tenant_private_key
  } do
    conn =
      conn
      |> authenticate_connection(tenant_private_key, %{e_tga: true})
      |> get(api_path, query: @query)

    assert json_response(conn, 200)
  end
end
