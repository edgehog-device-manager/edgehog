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

defmodule EdgehogWeb.AdminAPI.Auth.TokenTest do
  use ExUnit.Case, async: true

  alias EdgehogWeb.AdminAPI.Auth.Token

  describe "subject_for_token/2" do
    test "returns {:ok, \"test\"} for any resource and claims" do
      assert {:ok, "test"} = Token.subject_for_token(%{}, %{})
    end

    test "returns {:ok, \"test\"} with nil resource" do
      assert {:ok, "test"} = Token.subject_for_token(nil, %{})
    end

    test "returns {:ok, \"test\"} with empty claims" do
      assert {:ok, "test"} = Token.subject_for_token(%{id: 1}, %{})
    end
  end

  describe "resource_from_claims/1" do
    test "returns {:ok, %{claims: ...}} when e_ara claim is present" do
      claims = %{"e_ara" => %{"tenants" => ["*"]}}

      assert {:ok, %{claims: %{"tenants" => ["*"]}}} = Token.resource_from_claims(claims)
    end

    test "returns {:ok, %{claims: ...}} with wildcard e_ara claim" do
      claims = %{"e_ara" => "*"}

      assert {:ok, %{claims: "*"}} = Token.resource_from_claims(claims)
    end

    test "returns {:error, :no_valid_claims} when e_ara claim is missing" do
      claims = %{"sub" => "user123", "other" => "value"}

      assert {:error, :no_valid_claims} = Token.resource_from_claims(claims)
    end

    test "returns {:error, :no_valid_claims} with empty claims" do
      assert {:error, :no_valid_claims} = Token.resource_from_claims(%{})
    end

    test "returns {:error, :no_valid_claims} when other claims exist but not e_ara" do
      claims = %{
        "sub" => "admin",
        "iat" => 1_234_567_890,
        "exp" => 1_234_567_999
      }

      assert {:error, :no_valid_claims} = Token.resource_from_claims(claims)
    end
  end
end
