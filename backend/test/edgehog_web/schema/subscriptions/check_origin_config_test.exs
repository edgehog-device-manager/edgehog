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

defmodule EdgehogWeb.Schema.Subscriptions.CheckOriginConfigTest do
  use ExUnit.Case, async: false

  defp read_endpoint_config!(config_file, env) do
    config_file
    |> Config.Reader.read!(env: env, target: :host)
    |> Keyword.get(:edgehog, [])
    |> Keyword.fetch!(EdgehogWeb.Endpoint)
  end

  defp with_env(overrides, fun) do
    previous = for {key, _value} <- overrides, into: %{}, do: {key, System.get_env(key)}

    Enum.each(overrides, fn
      {key, nil} -> System.delete_env(key)
      {key, value} -> System.put_env(key, value)
    end)

    try do
      fun.()
    after
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end

  describe "config/dev.exs check_origin" do
    test "defaults to localhost origins when env var is not set" do
      with_env([{"GQL_SUBSCRIPTIONS_ALLOWED_ORIGINS", nil}], fn ->
        endpoint = read_endpoint_config!("config/dev.exs", :dev)

        assert Keyword.fetch!(endpoint, :check_origin) == ["//localhost", "//127.0.0.1"]
      end)
    end

    test "uses comma-separated GQL_SUBSCRIPTIONS_ALLOWED_ORIGINS" do
      with_env(
        [
          {"GQL_SUBSCRIPTIONS_ALLOWED_ORIGINS", "http://localhost:5173, http://edgehog.localhost"}
        ],
        fn ->
          endpoint = read_endpoint_config!("config/dev.exs", :dev)

          assert Keyword.fetch!(endpoint, :check_origin) == [
                   "http://localhost:5173",
                   "http://edgehog.localhost"
                 ]
        end
      )
    end
  end

  describe "config/runtime.exs check_origin" do
    test "defaults to URL_SCHEME://URL_HOST:URL_PORT in prod" do
      with_env(
        [
          {"DATABASE_USERNAME", "postgres"},
          {"DATABASE_PASSWORD", "postgres"},
          {"DATABASE_HOSTNAME", "localhost"},
          {"DATABASE_NAME", "edgehog"},
          {"SECRET_KEY_BASE", "test_secret_key_base"},
          {"URL_HOST", "api.edgehog.localhost"},
          {"URL_SCHEME", "https"},
          {"URL_PORT", "443"},
          {"GQL_SUBSCRIPTIONS_ALLOWED_ORIGINS", nil}
        ],
        fn ->
          endpoint = read_endpoint_config!("config/runtime.exs", :prod)

          assert Keyword.fetch!(endpoint, :check_origin) == ["https://api.edgehog.localhost:443"]
        end
      )
    end

    test "uses GQL_SUBSCRIPTIONS_ALLOWED_ORIGINS in prod when provided" do
      with_env(
        [
          {"DATABASE_USERNAME", "postgres"},
          {"DATABASE_PASSWORD", "postgres"},
          {"DATABASE_HOSTNAME", "localhost"},
          {"DATABASE_NAME", "edgehog"},
          {"SECRET_KEY_BASE", "test_secret_key_base"},
          {"URL_HOST", "api.edgehog.localhost"},
          {"URL_SCHEME", "https"},
          {"URL_PORT", "443"},
          {"GQL_SUBSCRIPTIONS_ALLOWED_ORIGINS",
           "https://ui.edgehog.localhost, https://ops.edgehog.localhost"}
        ],
        fn ->
          endpoint = read_endpoint_config!("config/runtime.exs", :prod)

          assert Keyword.fetch!(endpoint, :check_origin) == [
                   "https://ui.edgehog.localhost",
                   "https://ops.edgehog.localhost"
                 ]
        end
      )
    end
  end
end
