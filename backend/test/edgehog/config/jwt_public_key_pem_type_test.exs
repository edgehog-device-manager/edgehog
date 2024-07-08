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

defmodule Edgehog.Config.JWTPublicKeyPEMTypeTest do
  use ExUnit.Case, async: true

  alias Edgehog.Config.JWTPublicKeyPEMType
  alias JOSE.JWK

  @public_key_path "admin_public_key.pem"

  @valid_pem_public_key :secp256r1
                        |> X509.PrivateKey.new_ec()
                        |> X509.PublicKey.derive()
                        |> X509.PublicKey.to_pem()

  @invalid_public_key "-----BEGIN PUBLIC KEY-----MFkwEwYH_truncated"

  describe "cast/1" do
    test "returns JWK for valid public key passed by value" do
      assert {:ok, %JWK{}} = JWTPublicKeyPEMType.cast(@valid_pem_public_key)
    end

    test "returns JWK for valid public key passed by path" do
      File.open!(@public_key_path, [:write])
      File.write!(@public_key_path, @valid_pem_public_key)
      on_exit(fn -> File.rm!(@public_key_path) end)

      assert {:ok, %JWK{}} = JWTPublicKeyPEMType.cast(@public_key_path)
    end

    test "returns :error for not binary data" do
      assert :error == JWTPublicKeyPEMType.cast(nil)
    end

    test "raise for invalid public key passed by value" do
      assert_raise RuntimeError, fn ->
        JWTPublicKeyPEMType.cast(@invalid_public_key)
      end
    end

    test "raise if file does not exist" do
      assert_raise File.Error, fn ->
        JWTPublicKeyPEMType.cast(@public_key_path)
      end
    end

    test "raise for invalid public key passed by path" do
      File.open!(@public_key_path, [:write])
      File.write!(@public_key_path, @invalid_public_key)
      on_exit(fn -> File.rm!(@public_key_path) end)

      assert_raise RuntimeError, fn ->
        JWTPublicKeyPEMType.cast(@public_key_path)
      end
    end
  end
end
