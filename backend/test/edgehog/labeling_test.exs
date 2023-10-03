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

defmodule Edgehog.LabelingTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Devices
  alias Edgehog.Labeling
  alias Edgehog.Labeling.Tag

  setup do
    cluster = cluster_fixture()

    %{realm: realm_fixture(cluster)}
  end

  describe "list_device_tags/0" do
    test "return empty list" do
      assert [] == Labeling.list_device_tags()
    end

    test "returns tags for all devices", %{realm: realm} do
      _device1 =
        device_fixture(realm)
        |> add_tags(["foo"])

      _device2 =
        device_fixture(realm)
        |> add_tags(["bar"])

      assert [%Tag{name: "foo"}, %Tag{name: "bar"}] = Labeling.list_device_tags()
    end

    test "returns tags only if there're assigned to devices", %{realm: realm} do
      device =
        device_fixture(realm)
        |> add_tags(["foo"])

      _device = Devices.update_device(device, %{tags: []})

      assert [] == Labeling.list_device_tags()
    end

    test "returns tag assigned to a few devices once", %{realm: realm} do
      for _ <- 0..2 do
        _ =
          device_fixture(realm)
          |> add_tags(["foo"])
      end

      assert [%Tag{name: "foo"}] = Labeling.list_device_tags()
    end
  end
end
