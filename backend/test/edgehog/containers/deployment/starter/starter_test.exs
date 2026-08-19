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

defmodule Edgehog.Containers.Deployment.StarterTest do
  @moduledoc false

  use Edgehog.DataCase, async: true

  import Edgehog.TenantsFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.Deployment.Starter
  alias Edgehog.Containers.Deployment.Starter.Core

  setup do
    tenant = tenant_fixture()
    device = device_fixture(tenant: tenant)

    {:ok, starter} = Starter.cook(device, tenant, mode: :manual)
    ref = Process.monitor(starter)

    %{tenant: tenant, device: device, starter: starter, starter_ref: ref}
  end

  describe "Starter" do
    test "correctly starts loaded deployments", %{
      tenant: tenant,
      device: device,
      starter: starter,
      starter_ref: ref
    } do
      d1 = deployment_fixture(state: :pending, device_id: device.id, tenant: tenant)
      d2 = deployment_fixture(state: :pending, device_id: device.id, tenant: tenant)

      deployments = [d1, d2]

      Core
      |> allow(self(), starter)
      |> expect(:load, fn ^device, ^tenant ->
        {:ok, deployments}
      end)
      |> expect(:start, fn ^deployments, ^tenant ->
        []
      end)

      Starter.run(starter)

      # If everything went fine, starter shuts down normally
      assert_receive {:DOWN, ^ref, :process, ^starter, :normal}, 2000
    end

    test "with errors shuts down with `{:shutdown, {:errors, errors}}`", %{
      tenant: tenant,
      device: device,
      starter: starter,
      starter_ref: ref
    } do
      d1 = deployment_fixture(state: :pending, device_id: device.id, tenant: tenant)
      d2 = deployment_fixture(state: :pending, device_id: device.id, tenant: tenant)

      deployments = [d1, d2]
      errors = [{:error, :fake_error, d1}]

      Core
      |> allow(self(), starter)
      |> expect(:load, fn ^device, ^tenant ->
        {:ok, deployments}
      end)
      |> expect(:start, fn ^deployments, ^tenant ->
        errors
      end)

      Starter.run(starter)

      # If everything went fine, starter shuts down normally
      assert_receive {:DOWN, ^ref, :process, ^starter, {:shutdown, {:start_errors, ^errors}}},
                     2000
    end
  end
end
