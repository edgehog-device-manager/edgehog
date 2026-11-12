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

defmodule Edgehog.Containers.VolumeTest do
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.Volume

  describe "reclaim policy" do
    setup do
      tenant = tenant_fixture()
      %{tenant: tenant}
    end

    test "validates the reclaim policy on creation and update", %{tenant: tenant} do
      volume = volume_fixture(tenant: tenant)
      assert volume.reclaim_policy == "Delete"

      assert {:error, _} =
               Ash.create(Volume, %{label: unique_volume_label(), reclaim_policy: "Other"},
                 tenant: tenant
               )

      assert {:error, _} = Ash.update(volume, %{reclaim_policy: "Other"}, tenant: tenant)
      assert {:error, _} = Ash.update(volume, %{reclaim_policy: nil}, tenant: tenant)
      assert Ash.get!(Volume, volume.id, tenant: tenant).reclaim_policy == "Delete"
    end

    test "copies and hashes distinguish reclaim policies", %{tenant: tenant} do
      source = volume_fixture(tenant: tenant)
      params = %{label: source.label, driver: source.driver, source_volume_id: source.id}

      delete_copy =
        Ash.create!(Volume, Map.put(params, :reclaim_policy, "Delete"),
          action: :copy,
          tenant: tenant
        )

      retain_copy =
        Ash.create!(Volume, Map.put(params, :reclaim_policy, "Retain"),
          action: :copy,
          tenant: tenant
        )

      assert delete_copy.id != retain_copy.id
      assert retain_copy.reclaim_policy == "Retain"

      assert Ash.load!(delete_copy, :hash, tenant: tenant).hash !=
               Ash.load!(retain_copy, :hash, tenant: tenant).hash

      same_copy =
        Ash.create!(Volume, Map.put(params, :reclaim_policy, "Retain"),
          action: :copy,
          tenant: tenant
        )

      assert same_copy.id == retain_copy.id
    end
  end
end
