#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.DeploymentCampaigns.Lazy.CoreTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DeploymentCampaignsFixtures
  import Edgehog.TenantsFixtures

  alias Ash.Error.Invalid
  alias Edgehog.Astarte.Device.CreateDeploymentRequestMock
  alias Edgehog.DeploymentCampaigns.DeploymentMechanism.Lazy.Core
  alias Edgehog.Error.AstarteAPIError

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "retry_target_update/1" do
    setup %{tenant: tenant} do
      target = [tenant: tenant] |> in_progress_target_fixture() |> Ash.load!(:device)
      release = release_fixture(tenant: tenant)

      %{target: target, release: release}
    end

    test "succeeds if Astarte API replies with a success", ctx do
      %{
        target: target
      } = ctx

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, fn _client, _device_id, _data ->
        :ok
      end)

      assert :ok = Core.retry_target_operation(target, :deploy)
    end

    test "fails if Astarte API replies with a failure", ctx do
      %{
        target: target
      } = ctx

      expect(CreateDeploymentRequestMock, :send_create_deployment_request, fn _client, _device_id, _data ->
        {:error, %AstarteAPIError{status: 500, response: "Internal server error"}}
      end)

      assert {:error, reason} = Core.retry_target_operation(target, :deploy)

      assert %Invalid{
               errors: [
                 %AstarteAPIError{status: 500, response: "Internal server error"}
               ]
             } = reason
    end
  end
end
