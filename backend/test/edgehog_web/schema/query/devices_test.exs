#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.DevicesTest do
  use EdgehogWeb.GraphqlCase, async: true

  @moduletag :ported_to_ash

  import Edgehog.DevicesFixtures

  describe "devices query" do
    test "returns empty devices", %{tenant: tenant} do
      assert [] == devices_query(tenant: tenant) |> extract_result!()
    end

    test "returns devices if they're present", %{tenant: tenant} do
      fixture = device_fixture(tenant: tenant)

      assert [device] = devices_query(tenant: tenant) |> extract_result!()

      assert device["name"] == fixture.name
      assert device["deviceId"] == fixture.device_id
      assert device["online"] == fixture.online
    end

    test "allows filtering", %{tenant: tenant} do
      _ = device_fixture(tenant: tenant, name: "online-1", online: true)
      _ = device_fixture(tenant: tenant, name: "offline-1", online: false)
      _ = device_fixture(tenant: tenant, name: "online-2", online: true)

      filter = %{"online" => %{"eq" => true}}

      devices =
        devices_query(tenant: tenant, filter: filter)
        |> extract_result!()

      assert length(devices) == 2
      assert "online-1" in Enum.map(devices, & &1["name"])
      assert "online-2" in Enum.map(devices, & &1["name"])
      refute "offline-1" in Enum.map(devices, & &1["name"])
    end

    test "allows sorting", %{tenant: tenant} do
      _ = device_fixture(tenant: tenant, name: "b")
      _ = device_fixture(tenant: tenant, name: "a")
      _ = device_fixture(tenant: tenant, name: "c")

      sort = %{"field" => "NAME", "order" => "DESC"}

      assert [%{"name" => "c"}, %{"name" => "b"}, %{"name" => "a"}] =
               devices_query(tenant: tenant, sort: sort)
               |> extract_result!()
    end
  end

  defp devices_query(opts) do
    default_document =
      """
      query Devices($filter: DeviceFilterInput, $sort: [DeviceSortInput]) {
        devices(filter: $filter, sort: $sort) {
          name
          deviceId
          online
          lastConnection
          lastDisconnection
          serialNumber
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    variables =
      %{
        "filter" => opts[:filter],
        "sort" => opts[:sort] || []
      }

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"devices" => devices}} = result
    assert devices != nil

    devices
  end
end
