#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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
  use EdgehogWeb.ConnCase

  describe "forwarderConfig query" do
    @query """
    query {
      forwarderConfig {
        hostname
        port
        secureSessions
      }
    }
    """

    test "returns the forwarder config when the forwarder is configured", %{
      conn: conn,
      api_path: api_path
    } do
      original_config =
        mock_configured_forwarder(
          hostname: "some-hostname.com",
          port: 4001,
          secure_sessions?: true
        )

      result = run_query(conn, api_path)

      assert %{
               "data" => %{
                 "forwarderConfig" => %{
                   "hostname" => "some-hostname.com",
                   "port" => 4001,
                   "secureSessions" => true
                 }
               }
             } = result

      restore_forwarder_config(original_config)
    end

    test "returns null when the forwarder is not configured", %{
      conn: conn,
      api_path: api_path
    } do
      original_config = mock_unconfigured_forwarder()

      result = run_query(conn, api_path)

      assert %{
               "data" => %{
                 "forwarderConfig" => nil
               }
             } = result

      restore_forwarder_config(original_config)
    end
  end

  defp mock_configured_forwarder(
         hostname: hostname,
         port: port,
         secure_sessions?: secure_sessions?
       ) do
    original_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)

    Application.put_env(:edgehog, :edgehog_forwarder, %{
      hostname: hostname,
      port: port,
      secure_sessions?: secure_sessions?,
      enabled?: true
    })

    original_config
  end

  defp mock_unconfigured_forwarder() do
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

  defp run_query(conn, api_path) do
    conn
    |> get(api_path, query: @query, variables: %{})
    |> json_response(200)
  end
end
