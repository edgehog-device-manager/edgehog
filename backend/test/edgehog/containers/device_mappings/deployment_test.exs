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

defmodule Edgehog.Containers.DeviceMapping.DeploymentTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Astarte.Device.CreateContainerRequestMock
  alias Edgehog.Astarte.Device.CreateDeploymentRequestMock
  alias Edgehog.Astarte.Device.CreateDeviceMappingRequestMock
  alias Edgehog.Astarte.Device.CreateImageRequestMock

  setup do
    tenant = tenant_fixture()
    device_mapping = device_mapping_fixture(tenant: tenant)

    %{tenant: tenant, device_mapping: device_mapping}
  end

  describe "device mapping deployment" do
    test "gets created and sent to the device", %{tenant: tenant, device_mapping: device_mapping} do
      release1 =
        release_fixture(
          tenant: tenant,
          containers: 1,
          container_params: [device_mappings: [device_mapping.id]]
        )

      device = device_fixture(tenant: tenant)

      deployment =
        deployment_fixture(tenant: tenant, device_id: device.id, release_id: release1.id)

      expect(CreateImageRequestMock, :send_create_image_request, fn _, _, _ -> :ok end)

      expect(CreateDeviceMappingRequestMock, :send_create_device_mapping_request, fn _, _, _ ->
        :ok
      end)

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, fn _, _, _ ->
        :ok
      end)

      expect(CreateContainerRequestMock, :send_create_container_request, fn _, _, _ ->
        :ok
      end)

      deployment
      |> Ash.Changeset.for_update(:send_deployment, %{})
      |> Ash.update!(tenant: tenant)
    end
  end
end
