#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule Edgehog.Selector.AST.TagFilterTest do
  use Edgehog.DataCase, async: true

  import Ecto.Query
  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  alias Edgehog.Devices
  alias Edgehog.Selector.AST.TagFilter
  alias Edgehog.Repo

  describe "to_ecto_dynamic_query/1" do
    setup do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      device_foo =
        device_fixture(realm)
        |> add_tags(["foo", "other", "foox"])

      device_bar =
        device_fixture(realm, device_id: "7mcE8JeZQkSzjLyYuh5N9A")
        |> add_tags(["bar", "foox"])

      device_no_tags = device_fixture(realm, device_id: "nWwr7SZiR8CgZN_uKHsAJg")

      {:ok, device_foo: device_foo, device_bar: device_bar, device_no_tags: device_no_tags}
    end

    test "returns dynamic query that matches devices with the tag", %{device_foo: device_foo} do
      assert {:ok, dynamic} =
               %TagFilter{operator: :in, tag: "foo"}
               |> TagFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      assert [device_foo] ==
               Repo.all(query)
               # Preload the same associations preloaded in the Astarte context
               |> Devices.preload_defaults_for_device()
    end

    test "returns dynamic query that matches devices without the tag", %{
      device_bar: device_bar,
      device_no_tags: device_no_tags
    } do
      assert {:ok, dynamic} =
               %TagFilter{operator: :not_in, tag: "foo"}
               |> TagFilter.to_ecto_dynamic_query()

      query =
        from d in Devices.Device,
          where: ^dynamic

      result =
        Repo.all(query)
        # Preload the same associations preloaded in the Astarte context
        |> Devices.preload_defaults_for_device()

      assert is_list(result)
      assert length(result) == 2
      assert device_bar in result
      assert device_no_tags in result
    end
  end
end
