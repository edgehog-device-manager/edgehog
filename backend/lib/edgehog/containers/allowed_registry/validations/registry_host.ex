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

defmodule Edgehog.Containers.Validations.RegistryHost do
  @moduledoc false
  use Ash.Resource.Validation

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    host = Ash.Changeset.get_attribute(changeset, :registry)

    if valid_host?(host) do
      :ok
    else
      {:error,
       field: :registry, message: "must be a valid domain name, IPv4 address or [IPv6 address]"}
    end
  end

  defp valid_host?(host) when is_binary(host) do
    cond do
      ipv4_format?(host) -> valid_ipv4?(host)
      String.contains?(host, ":") -> valid_ipv6?(host)
      true -> valid_domain?(host)
    end
  end

  defp valid_host?(_), do: false

  defp valid_ipv4?(host) do
    host
    |> String.to_charlist()
    |> :inet.parse_ipv4_address()
    |> parse_result_valid?()
  end

  defp valid_ipv6?(address) do
    address
    |> String.to_charlist()
    |> :inet.parse_ipv6_address()
    |> parse_result_valid?()
  end

  defp parse_result_valid?({:ok, _}), do: true
  defp parse_result_valid?(_), do: false

  defp valid_domain?(host) do
    String.length(host) <= 253 and
      host
      |> String.split(".")
      |> Enum.all?(&valid_domain_label?/1)
  end

  defp valid_domain_label?(label) do
    String.length(label) in 1..63 and
      Regex.match?(
        ~r/\A[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\z/,
        label
      )
  end

  defp ipv4_format?(host) do
    Regex.match?(~r/\A\d{1,3}(?:\.\d{1,3}){3}\z/, host)
  end
end
