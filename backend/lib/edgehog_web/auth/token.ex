# This file is part of Edgehog.
#
# Copyright 2022, 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Auth.Token do
  @moduledoc false
  use Guardian, otp_app: :edgehog

  # This is used only when signing tokens, and we just want to verify them
  # However, we want to be able to generate tokens for testing purposes or
  # allow developers to generate tokens for their local dev environments.
  # For this reason we provide an implementation only for these envs
  if Mix.env() in [:test, :dev] do
    def subject_for_token(_resource, _claims) do
      {:ok, "test"}
    end
  else
    def subject_for_token(_resource, _claims) do
      {:error, :cannot_sign}
    end
  end

  def resource_from_claims(claims) do
    # TODO: for now we just check that some e_tga claims are encoded in the token,
    # and we don't care about their value
    # e_tga = Edgehog Tenant GraphQL API
    # The same is true for the OpenID connect claims required by Edgehog
    # but only e_tga is used for validating auth for now
    case Map.fetch(claims, "e_tga") do
      {:ok, e_tga_value} ->
        claims = oidc_claims(claims)

        Edgehog.Actors.Actor
        |> Ash.Changeset.for_create(
          :from_claims,
          Map.put(claims, :claims, %{e_tga: e_tga_value})
        )
        |> Ash.create()

      :error ->
        {:error, :no_valid_claims}
    end
  end

  defp oidc_claims(submitted_claims) when is_map(submitted_claims) do
    required_claims = [
      :sub,
      :aud,
      :exp,
      :iat,
      :auth_time,
      :preferred_username,
      :email,
      :given_name,
      :family_name
    ]

    Enum.reduce(required_claims, %{}, fn claim_name, acc ->
      case Map.fetch(submitted_claims, Atom.to_string(claim_name)) do
        {:ok, value} -> Map.put(acc, claim_name, timestamp_to_datetime(value))
        _ -> acc
      end
    end)
  end

  defp timestamp_to_datetime(timestamp_or_else) when is_integer(timestamp_or_else) do
    case DateTime.from_unix(timestamp_or_else) do
      {:ok, dt} -> dt
      {:error, _} -> nil
    end
  end

  defp timestamp_to_datetime(timestamp_or_else), do: timestamp_or_else
end
