#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule EdgehogWeb.GqlSocketTest do
  use Edgehog.DataCase, async: true

  import Edgehog.TenantsFixtures
  import Phoenix.ChannelTest

  alias EdgehogWeb.Auth.Token
  alias EdgehogWeb.GqlSocket

  @endpoint EdgehogWeb.Endpoint

  setup do
    tenant_private_key = X509.PrivateKey.new_ec(:secp256r1)

    tenant_public_key =
      tenant_private_key
      |> X509.PublicKey.derive()
      |> X509.PublicKey.to_pem()

    tenant = tenant_fixture(public_key: tenant_public_key)

    jwk =
      tenant_private_key
      |> X509.PrivateKey.to_pem()
      |> JOSE.JWK.from_pem()

    %{tenant: tenant, jwk: jwk, tenant_private_key: tenant_private_key}
  end

  describe "connect/3" do
    test "connects with valid token and tenant", %{tenant: tenant, jwk: jwk} do
      claims = %{e_tga: true}

      {:ok, jwt, _claims} =
        Token.encode_and_sign("dontcare", claims,
          secret: jwk,
          allowed_algos: ["ES256"]
        )

      params = %{
        "token" => jwt,
        "tenant" => tenant.slug
      }

      assert {:ok, socket} = connect(GqlSocket, params)
      assert socket.assigns.tenant.tenant_id == tenant.tenant_id
    end

    test "connects with valid token that includes exp claim", %{tenant: tenant, jwk: jwk} do
      future_exp = Joken.current_time() + 3600
      claims = %{e_tga: true, exp: future_exp}

      {:ok, jwt, _claims} =
        Token.encode_and_sign("dontcare", claims,
          secret: jwk,
          allowed_algos: ["ES256"]
        )

      params = %{
        "token" => jwt,
        "tenant" => tenant.slug
      }

      assert {:ok, socket} = connect(GqlSocket, params)
      assert socket.assigns.tenant.tenant_id == tenant.tenant_id
    end

    test "connects and normalizes token with escaped newlines", %{tenant: tenant, jwk: jwk} do
      {:ok, jwt, _} =
        Token.encode_and_sign("sub", %{e_tga: true}, secret: jwk, allowed_algos: ["ES256"])

      # Inject an escaped newline into the JWT string
      escaped_jwt = String.slice(jwt, 0..10) <> "\\n" <> String.slice(jwt, 11..-1//1)

      params = %{
        "token" => escaped_jwt,
        "tenant" => tenant.slug
      }

      # The code's String.replace(token, "\\n", "") will clean this up
      assert {:ok, _socket} = connect(GqlSocket, params)
    end

    test "rejects connection with expired token", %{tenant: tenant, jwk: jwk} do
      past_exp = Joken.current_time() - 3600
      claims = %{e_tga: true, exp: past_exp}

      {:ok, jwt, _claims} =
        Token.encode_and_sign("dontcare", claims,
          secret: jwk,
          allowed_algos: ["ES256"]
        )

      params = %{
        "token" => jwt,
        "tenant" => tenant.slug
      }

      assert {:error, :token_expired} = connect(GqlSocket, params)
    end

    test "rejects connection with invalid token", %{tenant: tenant} do
      params = %{
        "token" => "invalid_token",
        "tenant" => tenant.slug
      }

      assert {:error, _reason} = connect(GqlSocket, params)
    end

    test "rejects connection with non-existing tenant", %{jwk: jwk} do
      claims = %{e_tga: true}

      {:ok, jwt, _claims} =
        Token.encode_and_sign("dontcare", claims,
          secret: jwk,
          allowed_algos: ["ES256"]
        )

      params = %{
        "token" => jwt,
        "tenant" => "non_existing_tenant"
      }

      assert {:error, _reason} = connect(GqlSocket, params)
    end

    test "rejects connection without parameters" do
      assert {:error, %{reason: "unauthorized", message: "Missing params"}} =
               connect(GqlSocket, %{})
    end

    test "rejects connection with missing token", %{tenant: tenant} do
      params = %{
        "tenant" => tenant.slug
      }

      assert {:error, %{reason: "unauthorized", message: "Missing params"}} =
               connect(GqlSocket, params)
    end

    test "rejects connection with missing tenant", %{jwk: jwk} do
      claims = %{e_tga: true}

      {:ok, jwt, _claims} =
        Token.encode_and_sign("dontcare", claims,
          secret: jwk,
          allowed_algos: ["ES256"]
        )

      params = %{
        "token" => jwt
      }

      assert {:error, %{reason: "unauthorized", message: "Missing params"}} =
               connect(GqlSocket, params)
    end

    test "rejects connection with claims missing e_tga", %{tenant: tenant, jwk: jwk} do
      claims = %{some_other_claim: true}

      {:ok, jwt, _claims} =
        Token.encode_and_sign("dontcare", claims,
          secret: jwk,
          allowed_algos: ["ES256"]
        )

      params = %{
        "token" => jwt,
        "tenant" => tenant.slug
      }

      assert {:error, :invalid_claims} = connect(GqlSocket, params)
    end

    test "connects with RSA key", %{tenant: _tenant} do
      # Create a tenant with RSA key
      rsa_private_key = X509.PrivateKey.new_rsa(2048)

      rsa_public_key =
        rsa_private_key
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()

      tenant = tenant_fixture(public_key: rsa_public_key)

      jwk =
        rsa_private_key
        |> X509.PrivateKey.to_pem()
        |> JOSE.JWK.from_pem()

      claims = %{e_tga: true}

      {:ok, jwt, _claims} =
        Token.encode_and_sign("dontcare", claims,
          secret: jwk,
          allowed_algos: ["RS256"]
        )

      params = %{
        "token" => jwt,
        "tenant" => tenant.slug
      }

      assert {:ok, socket} = connect(GqlSocket, params)
      assert socket.assigns.tenant.tenant_id == tenant.tenant_id
    end
  end

  describe "id/1" do
    test "returns socket id based on tenant slug", %{tenant: tenant, jwk: jwk} do
      claims = %{e_tga: true}

      {:ok, jwt, _claims} =
        Token.encode_and_sign("dontcare", claims,
          secret: jwk,
          allowed_algos: ["ES256"]
        )

      params = %{
        "token" => jwt,
        "tenant" => tenant.slug
      }

      {:ok, socket} = connect(GqlSocket, params)
      assert GqlSocket.id(socket) == "gql_socket:#{tenant.slug}"
    end
  end
end
