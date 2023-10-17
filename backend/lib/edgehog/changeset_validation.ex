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

defmodule Edgehog.ChangesetValidation do
  import Ecto.Changeset

  def validate_tenant_slug(changeset, field) do
    validate_format(changeset, field, ~r/^[a-z\d\-]+$/,
      message: "should only contain lower case ASCII letters (from a to z), digits and -"
    )
  end

  def validate_realm_name(changeset, field) do
    validate_format(changeset, field, ~r/^[a-z][a-z0-9]{0,47}$/,
      message:
        "should only contain lower case ASCII letters (from a to z) and digits, " <>
          "and start with a lower case ASCII letter"
    )
  end

  def validate_locale(changeset, field) do
    validate_format(changeset, field, ~r/^[a-z]{2,3}-[A-Z]{2}$/, message: "is not a valid locale")
  end

  def validate_pem_public_key(changeset, field) do
    validate_change(changeset, field, fn field, pem_public_key ->
      case X509.PublicKey.from_pem(pem_public_key) do
        {:ok, _} -> []
        {:error, _reason} -> [{field, "is not a valid PEM public key"}]
      end
    end)
  end

  def validate_pem_private_key(changeset, field) do
    validate_change(changeset, field, fn field, pem_private_key ->
      case X509.PrivateKey.from_pem(pem_private_key) do
        {:ok, _} -> []
        {:error, _reason} -> [{field, "is not a valid PEM private key"}]
      end
    end)
  end

  def validate_url(changeset, field) do
    validate_change(changeset, field, fn field, url ->
      %URI{scheme: scheme, host: maybe_host} = URI.parse(url)

      host = to_string(maybe_host)
      empty_host? = host == ""
      space_in_host? = host =~ " "

      valid_host? = not empty_host? and not space_in_host?
      valid_scheme? = scheme in ["http", "https"]

      if valid_host? and valid_scheme? do
        []
      else
        [{field, "is not a valid URL"}]
      end
    end)
  end
end
