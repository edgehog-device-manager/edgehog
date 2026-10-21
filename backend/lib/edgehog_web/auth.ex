#
# This file is part of Edgehog.
#
# Copyright 2022-2026 SECO Mind Srl
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

defmodule EdgehogWeb.Auth do
  @moduledoc false
  alias Edgehog.Tenants
  alias EdgehogWeb.Auth.Pipeline
  alias EdgehogWeb.Auth.Token
  alias JOSE.JWK

  def init(opts) do
    Pipeline.init(opts)
  end

  def call(conn, opts) do
    Pipeline.call(conn, opts)
  end

  @doc """
  Authenticates a `tenant_slug` and JWT `auth_token` using Guardian (`EdgehogWeb.Auth.Token`)
  verified against the tenant's configured public key.

  Returns `{:ok, tenant, actor}` on success or `{:error, field, message}` on failure.
  """
  def authenticate_tenant(tenant_slug, auth_token)
      when is_binary(tenant_slug) and is_binary(auth_token) do
    tenant_slug = String.trim(tenant_slug)
    auth_token = String.trim(auth_token)

    with {:ok, tenant} <- fetch_tenant(tenant_slug),
         {:ok, jwk} <- parse_public_key(tenant.public_key),
         {:ok, actor} <- verify_token_with_guardian(auth_token, jwk) do
      {:ok, tenant, actor}
    end
  end

  defp fetch_tenant(""), do: {:error, :tenant_slug, "is required"}

  defp fetch_tenant(tenant_slug) do
    if Regex.match?(~r/^[a-z0-9\-]+$/, tenant_slug) do
      case Tenants.fetch_tenant_by_slug(tenant_slug) do
        {:ok, tenant} -> {:ok, tenant}
        {:error, _} -> {:error, :tenant_slug, "could not be found"}
      end
    else
      {:error, :tenant_slug, "must contain only lowercase letters, numbers, and hyphens"}
    end
  end

  defp parse_public_key(public_key) when is_binary(public_key) do
    normalized_pem = String.replace(public_key, "\\n", "\n")

    case JWK.from_pem(normalized_pem) do
      %JWK{} = jwk -> {:ok, jwk}
      _ -> {:error, :tenant_slug, "has an invalid public key configuration"}
    end
  end

  defp verify_token_with_guardian("", _jwk), do: {:error, :auth_token, "is required"}

  defp verify_token_with_guardian(auth_token, jwk) do
    clean_token = String.replace(auth_token, "\\n", "")

    case Token.resource_from_token(clean_token, %{}, secret: jwk) do
      {:ok, actor, _claims} ->
        {:ok, actor}

      {:error, :token_expired} ->
        {:error, :auth_token, "has expired"}

      {:error, :no_valid_claims} ->
        {:error, :auth_token, "is missing required Edgehog claims (e_tga)"}

      {:error, _reason} ->
        {:error, :auth_token, "is invalid for this tenant"}
    end
  end
end
