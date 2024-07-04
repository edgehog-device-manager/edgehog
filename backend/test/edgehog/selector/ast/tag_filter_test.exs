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

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Devices.Device
  alias Edgehog.Selector.AST.TagFilter
  alias Edgehog.Selector.Filter

  require Ash.Query

  describe "to_ash_expr/1" do
    setup do
      tenant = tenant_fixture()
      cluster = cluster_fixture()
      realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)

      device_foo =
        [realm_id: realm.id, tenant: tenant]
        |> device_fixture()
        |> add_tags(["foo", "other", "foox"])

      device_bar =
        [realm_id: realm.id, tenant: tenant]
        |> device_fixture()
        |> add_tags(["bar", "foox"])

      device_no_tags =
        device_fixture(realm_id: realm.id, tenant: tenant)

      {:ok, tenant: tenant, device_foo: device_foo, device_bar: device_bar, device_no_tags: device_no_tags}
    end

    test "returns expression that matches devices with the tag", ctx do
      %{tenant: tenant, device_foo: device_foo} = ctx

      expr =
        Filter.to_ash_expr(%TagFilter{operator: :in, tag: "foo"})

      assert [device] =
               Device
               |> Ash.Query.filter(^expr)
               |> Ash.read!(tenant: tenant, load: :tags)

      assert device.id == device_foo.id
    end

    test "returns dynamic query that matches devices without the tag", ctx do
      %{
        tenant: tenant,
        device_bar: device_bar,
        device_no_tags: device_no_tags
      } = ctx

      expr =
        Filter.to_ash_expr(%TagFilter{operator: :not_in, tag: "foo"})

      ids =
        Device
        |> Ash.Query.filter(^expr)
        |> Ash.list!(:id, tenant: tenant)

      assert is_list(ids)
      assert length(ids) == 2
      assert device_bar.id in ids
      assert device_no_tags.id in ids
    end
  end
end
