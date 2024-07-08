#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Query.ExistingDeviceTagsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.DevicesFixtures

  describe "existingDeviceTags query" do
    test "returns empty tags", %{tenant: tenant} do
      assert [] == [tenant: tenant] |> existing_device_tags_query() |> extract_result!()
    end

    test "returns tags if they're present", %{tenant: tenant} do
      [tenant: tenant]
      |> device_fixture()
      |> Ash.Changeset.for_update(:add_tags, tags: ["foo", "bar"])
      |> Ash.update!()

      assert tags = [tenant: tenant] |> existing_device_tags_query() |> extract_result!()
      assert length(tags) == 2
      tag_names = Enum.map(tags, &Map.fetch!(&1, "name"))
      assert "foo" in tag_names
      assert "bar" in tag_names
    end

    test "returns only tags currently assigned to some device", %{tenant: tenant} do
      [tenant: tenant]
      |> device_fixture()
      |> Ash.Changeset.for_update(:add_tags, tags: ["foo", "bar"])
      |> Ash.update!()
      |> Ash.Changeset.for_update(:remove_tags, tags: ["foo"])
      |> Ash.update!()

      assert [%{"name" => "bar"}] ==
               [tenant: tenant] |> existing_device_tags_query() |> extract_result!()
    end

    test "does not return duplicates if a tag is assigned multiple times", %{tenant: tenant} do
      [tenant: tenant]
      |> device_fixture()
      |> Ash.Changeset.for_update(:add_tags, tags: ["foo", "bar"])
      |> Ash.update!()

      [tenant: tenant]
      |> device_fixture()
      |> Ash.Changeset.for_update(:add_tags, tags: ["foo", "baz"])
      |> Ash.update!()

      assert tags = [tenant: tenant] |> existing_device_tags_query() |> extract_result!()
      assert length(tags) == 3
      tag_names = Enum.map(tags, &Map.fetch!(&1, "name"))
      assert "foo" in tag_names
      assert "bar" in tag_names
      assert "baz" in tag_names
    end
  end

  defp existing_device_tags_query(opts) do
    document = """
    query {
      existingDeviceTags {
        name
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: %{"existingDeviceTags" => tags}} = result
    assert tags != nil

    tags
  end
end
