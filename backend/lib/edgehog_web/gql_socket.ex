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

  channel "__absinthe__:control", Absinthe.Phoenix.Channel
  channel "rooms:*", EdgehogWeb.Channel.RoomChannel

  @impl true
  def connect(%{"Authorization" => token, "tenant" => tenant_slug}, socket, _connect_info) do
    with {:ok, tenant} <- Tenants.fetch_tenant_by_slug(tenant_slug),
         {:ok, claims} <- verify_jwt(token, tenant) do
      socket =
        socket
        |> assign(:current_tenant, tenant)
        |> assign(:claims, claims)
        |> Absinthe.Phoenix.Socket.put_options(
          context: %{
            current_tenant: tenant,
            claims: claims
          }
        )

      {:ok, socket}
    else
      {:error, :tenant_not_found} ->
        {:error, %{reason: "tenant_not_found"}}

      {:error, _reason} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def connect(_params, _socket, _connect_info) do
    {:error, %{reason: "unauthorized", message: "Missing params"}}
  end

  def id(_socket), do: nil

  defp verify_jwt(token_header, tenant) do
    token = String.replace_prefix(token_header, "Bearer ", "")

    normalized_public_key = String.replace(tenant.public_key, "\\n", "\n")

    jwk = JOSE.JWK.from_pem(normalized_public_key)

    {_kty, jwk_map} = JOSE.JWK.to_map(jwk)

    signer = Joken.Signer.create("ES256", jwk_map)

    case Joken.verify(token, signer, []) do
      {:ok, claims} ->
        {:ok, claims}

      {:error, _reason} ->
        {:error, :invalid_token}
    end
  end
end
