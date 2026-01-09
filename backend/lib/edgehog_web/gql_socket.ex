#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule EdgehogWeb.GqlSocket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: EdgehogWeb.Schema

  alias Edgehog.Tenants

  def connect(%{"token" => token, "tenant" => tenant_slug}, socket, _connect_info) do
    with {:ok, tenant} <- Tenants.fetch_tenant_by_slug(tenant_slug),
         {:ok, claims} <- verify_jwt(token, tenant) do
      socket =
        socket
        |> assign(:tenant, tenant)
        |> assign(:claims, claims)

      {:ok, socket}
    end
  end

  def connect(_params, _socket, _connect_info) do
    {:error, %{reason: "unauthorized", message: "Missing params"}}
  end

  def id(socket) do
    "gql_socket:#{socket.assigns.tenant.slug}"
  end

  defp verify_jwt(token, tenant) do
    token = String.replace(token, "\\n", "")
    normalized_public_key = String.replace(tenant.public_key, "\\n", "\n")
    jwk = JOSE.JWK.from_pem(normalized_public_key)
    {_kty, jwk_map} = JOSE.JWK.to_map(jwk)

    with {:ok, signer} <- signer_from_jwk_map(jwk_map),
         {:ok, claims} <- Joken.verify(token, signer, []) do
      validate_jwt_claims(claims)
    end
  end

  defp signer_from_jwk_map(%{"kty" => "RSA"} = jwk_map), do: {:ok, Joken.Signer.create("RS256", jwk_map)}

  defp signer_from_jwk_map(%{"kty" => "EC"} = jwk_map), do: {:ok, Joken.Signer.create("ES256", jwk_map)}

  defp signer_from_jwk_map(_), do: {:error, :unsupported_key_type}

  defp validate_jwt_claims(%{"exp" => exp, "e_tga" => _e_tga} = claims) when is_map(claims) do
    case check_jwt_expire(exp) do
      :ok -> {:ok, claims}
      error -> error
    end
  end

  defp validate_jwt_claims(%{"e_tga" => _e_tga} = claims) when is_map(claims) do
    {:ok, claims}
  end

  defp validate_jwt_claims(_), do: {:error, :invalid_claims}

  defp check_jwt_expire(exp) when is_integer(exp) do
    if exp > Joken.current_time(), do: :ok, else: {:error, :token_expired}
  end

  defp check_jwt_expire(_exp), do: {:error, :invalid_claims}
end
