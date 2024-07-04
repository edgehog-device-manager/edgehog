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

defmodule Edgehog.Astarte.ClusterTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures

  alias Ash.Error.Invalid
  alias Edgehog.Astarte
  alias Edgehog.Astarte.Cluster

  describe "create/1" do
    @valid_attrs %{base_api_url: "http://some-base-api.url", name: "some name"}
    @invalid_attrs %{base_api_url: nil, name: nil}

    test "with valid data creates a cluster" do
      %{base_api_url: url, name: name} = @valid_attrs

      assert {:ok, %Cluster{} = cluster} = Astarte.create_cluster(@valid_attrs)
      assert cluster.base_api_url == url
      assert cluster.name == name
    end

    test "creates cluster without name" do
      %{base_api_url: url} = @valid_attrs

      assert {:ok, %Cluster{} = cluster} = Astarte.create_cluster(%{base_api_url: url})
      assert cluster.base_api_url == url
      assert cluster.name == nil
    end

    test "strips trailing slash from base_api_url" do
      attrs = %{base_api_url: "https://api.test.astarte.example/foo/", name: "test-trailing"}

      assert {:ok, %Cluster{} = cluster} = Astarte.create_cluster(attrs)
      assert cluster.base_api_url == "https://api.test.astarte.example/foo"
    end

    test "with invalid data returns error" do
      %{name: valid_name} = @valid_attrs
      %{base_api_url: invalid_url} = @invalid_attrs

      invalid_attrs_list = [
        @invalid_attrs,
        %{base_api_url: invalid_url, name: valid_name},
        %{base_api_url: "", name: valid_name},
        %{base_api_url: "some url", name: valid_name}
      ]

      invalid_attrs_list
      |> Enum.map(&Astarte.create_cluster/1)
      |> Enum.each(fn result -> assert {:error, %Invalid{}} = result end)
    end

    test "with invalid URL schema returns error" do
      %{name: valid_name} = @valid_attrs

      valid_host_name = "host.com"
      invalid_schemas = ["ftp://", ""]

      Enum.each(invalid_schemas, fn schema ->
        assert {:error, %Invalid{}} =
                 Astarte.create_cluster(%{
                   base_api_url: schema <> valid_host_name,
                   name: valid_name
                 })
      end)
    end

    test "with invalid URL host returns error" do
      %{name: valid_name} = @valid_attrs
      valid_schema = "http://"
      invalid_hosts = ["some url", ""]

      Enum.each(invalid_hosts, fn host ->
        assert {:error, %Invalid{}} =
                 Astarte.create_cluster(%{base_api_url: valid_schema <> host, name: valid_name})
      end)
    end

    test "succeeds when upserting with the exact same data" do
      cluster = cluster_fixture()

      assert {:ok, upserted_cluster} =
               Astarte.create_cluster(%{base_api_url: cluster.base_api_url, name: cluster.name})

      assert upserted_cluster.name == cluster.name
      assert upserted_cluster.base_api_url == cluster.base_api_url
    end

    test "with existing base_api_url succeeds and doesn't update the name" do
      cluster = cluster_fixture()

      assert {:ok, upserted_cluster} =
               Astarte.create_cluster(%{base_api_url: cluster.base_api_url, name: "other"})

      assert upserted_cluster.name == cluster.name
    end
  end
end
