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

defmodule Edgehog.Config.JWTPublicKeyPEMType do
  use Skogsra.Type

  alias JOSE.JWK

  @impl Skogsra.Type
  @spec cast(term()) :: {:ok, JOSE.JWK.t()} | :error | no_return()
  def cast(value)

  def cast(value) when is_binary(value) do
    public_key = extract_pem!(value)

    case JWK.from_pem(public_key) do
      %JWK{} = jwk ->
        {:ok, jwk}

      _ ->
        raise "invalid JWT public key."
    end
  end

  def cast(_), do: :error

  defp extract_pem!("-----BEGIN PUBLIC KEY-----" <> _rest = pem) do
    pem
  end

  defp extract_pem!(path), do: File.read!(path)
end
