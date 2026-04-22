#
# This file is part of Edgehog.
#
# Copyright 2024 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.ForwarderConfigTest do
  use EdgehogWeb.GraphqlCase, async: true

  describe "forwarderConfig query" do
    test "returns the forwarder config when the forwarder is configured", %{tenant: tenant} do
      original_config =
        mock_configured_forwarder(
          hostname: "some-hostname.com",
          port: 4001,
          secure_sessions?: true
        )

      forwarder_config = [tenant: tenant] |> run_query() |> extract_result!()

      assert %{
               "hostname" => "some-hostname.com",
               "port" => 4001,
               "secureSessions" => true
             } = forwarder_config

      restore_forwarder_config(original_config)
    end

    test "returns null when the forwarder is not configured", %{tenant: tenant} do
      original_config = mock_unconfigured_forwarder()

      forwarder_config = [tenant: tenant] |> run_query() |> extract_result!()

      assert is_nil(forwarder_config)

      restore_forwarder_config(original_config)
    end
  end

  defp mock_configured_forwarder(hostname: hostname, port: port, secure_sessions?: secure_sessions?) do
    original_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)

    Application.put_env(:edgehog, :edgehog_forwarder, %{
      hostname: hostname,
      port: port,
      secure_sessions?: secure_sessions?,
      enabled?: true
    })

    original_config
  end

  defp mock_unconfigured_forwarder do
    original_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)

    Application.put_env(:edgehog, :edgehog_forwarder, %{
      hostname: nil,
      port: nil,
      secure_sessions?: false,
      enabled?: false
    })

    original_config
  end

  defp restore_forwarder_config(config) do
    Application.put_env(:edgehog, :edgehog_forwarder, config)
  end

  defp run_query(opts) do
    document = """
    query {
      forwarderConfig {
        hostname
        port
        secureSessions
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "forwarderConfig" => forwarder_config
             }
           } = result

    refute Map.get(result, :errors)

    forwarder_config
  end
end
