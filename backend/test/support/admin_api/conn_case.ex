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

defmodule EdgehogWeb.AdminAPI.ConnCase do
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

  alias Ecto.Adapters.SQL
  alias EdgehogWeb.Auth.Token

  using do
    quote do
      use EdgehogWeb, :verified_routes

      import EdgehogWeb.AdminAPI.ConnCase
      import Mox
      import Phoenix.ConnTest

      # Import conveniences for testing with connections
      import Plug.Conn

      # The default endpoint for testing
      @endpoint EdgehogWeb.Endpoint
    end
  end

  setup tags do
    pid = SQL.Sandbox.start_owner!(Edgehog.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
      |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")

    cond do
      tags[:unconfigured] ->
        [conn: conn]

      tags[:unauthenticated] ->
        admin_private_key = configure_authentication()
        [conn: conn, admin_private_key: admin_private_key]

      true ->
        admin_private_key = configure_authentication()
        conn = authenticate_connection(conn, admin_private_key)
        [conn: conn, admin_private_key: admin_private_key]
    end
  end

  @doc """
  Setup Admin authentication via public key.
  Returns private key.
  """
  def configure_authentication(private_key \\ X509.PrivateKey.new_ec(:secp256r1)) do
    private_key
    |> X509.PublicKey.derive()
    |> X509.PublicKey.to_pem()
    |> JOSE.JWK.from_pem()
    |> Edgehog.Config.put_admin_jwk()

    private_key
  end

  @doc """
  Authenticates the conn with Admin API claims
  """
  def authenticate_connection(conn, admin_private_key, claims \\ nil) do
    jwk =
      admin_private_key
      |> X509.PrivateKey.to_pem()
      |> JOSE.JWK.from_pem()

    # The value of e_ara claims is ignored for now
    claims = claims || %{e_ara: "*"}

    # Generate the JWT
    {:ok, jwt, _claims} =
      Token.encode_and_sign("dontcare", claims,
        secret: jwk,
        allowed_algos: ["ES256"]
      )

    Plug.Conn.put_req_header(conn, "authorization", "bearer #{jwt}")
  end
end
