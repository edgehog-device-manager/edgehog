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

defmodule EdgehogWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use EdgehogWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  use EdgehogWeb, :verified_routes

  using do
    quote do
      use EdgehogWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import EdgehogWeb.ConnCase
      import Mox

      alias EdgehogWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint EdgehogWeb.Endpoint
    end
  end

  alias Ecto.Adapters.SQL
  alias EdgehogWeb.Auth.Token

  setup tags do
    pid = SQL.Sandbox.start_owner!(Edgehog.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)

    conn = Phoenix.ConnTest.build_conn()

    # We manually generate the keypair so we can sign a JWT with it below
    tenant_private_key = X509.PrivateKey.new_ec(:secp256r1)

    tenant_public_key =
      tenant_private_key
      |> X509.PublicKey.derive()
      |> X509.PublicKey.to_pem()

    # Create a tenant fixture
    tenant = Edgehog.TenantsFixtures.tenant_fixture(public_key: tenant_public_key)

    # Populate the API path since it's tenant-specific
    api_path = ~p"/tenants/#{tenant.slug}/api"

    {:ok, conn: conn, tenant: tenant, api_path: api_path, tenant_private_key: tenant_private_key}
  end

  @doc """
  Authenticates the conn with Edgehog claims
  """
  def authenticate_connection(conn, tenant_private_key, claims \\ nil) do
    jwk =
      tenant_private_key
      |> X509.PrivateKey.to_pem()
      |> JOSE.JWK.from_pem()

    # The value of e_tga claims is ignored for now
    claims = claims || %{e_tga: true}

    # Generate the JWT
    {:ok, jwt, _claims} =
      Token.encode_and_sign("dontcare", claims,
        secret: jwk,
        allowed_algos: ["ES256"]
      )

    Plug.Conn.put_req_header(conn, "authorization", "bearer #{jwt}")
  end
end
