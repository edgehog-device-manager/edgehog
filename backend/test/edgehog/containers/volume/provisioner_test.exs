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

defmodule Edgehog.Containers.Volume.Deployment.ProvisionerTest do
  @moduledoc """
  Tests for the volume deployment provisioner.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.CreateVolumeRequest
  alias Edgehog.Containers.Volume.Deployment.Provisioner

  describe "Volume deployment provisioner" do
    setup do
      tenant = tenant_fixture()

      deployment =
        deployment_fixture(
          tenant: tenant,
          release_opts: [containers: 1, container_params: [volumes: 1]]
        )

      volume_deployment =
        deployment
        |> Ash.load!(container_deployments: [volume_deployments: :volume])
        |> Map.get(:container_deployments, [])
        |> List.first()
        |> Map.get(:volume_deployments, [])
        |> List.first()

      provisioner =
        Provisioner.start_link(
          tenant: tenant,
          volume_deployment: volume_deployment,
          deployment: deployment,
          mode: :manual
        )

      provisioner =
        case provisioner do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      ref = Process.monitor(provisioner)

      %{
        tenant: tenant,
        deployment: deployment,
        volume_deployment: volume_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      }
    end

    test "sets-up an volume on a device", context do
      %{
        volume_deployment: volume_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateVolumeRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_volume_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateVolumeRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          driver: driver,
          options: options
        } = data

        assert id == volume_deployment.volume.id
        assert deployment_id == deployment.id
        assert driver == volume_deployment.volume.driver
        assert options == Enum.into(volume_deployment.volume.options, [])

        # Update the volume deployment to be ready

        volume_deployment
        |> Ash.Changeset.for_update(:mark_as_unavailable, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.start(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up an volume on a device after a retry", context do
      %{
        volume_deployment: volume_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateVolumeRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_volume_request, fn _, _, _ ->
        {:error, %Astarte.Client.APIError{status: 500, response: "some error message"}}
      end)
      |> expect(:send_create_volume_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateVolumeRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          driver: driver,
          options: options
        } = data

        assert id == volume_deployment.volume.id
        assert deployment_id == deployment.id
        assert driver == volume_deployment.volume.driver
        assert options == Enum.into(volume_deployment.volume.options, [])

        volume_deployment
        |> Ash.Changeset.for_update(:mark_as_unavailable, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.start(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "emits :ready on correct topic on provisioning completion", context do
      %{
        volume_deployment: volume_deployment,
        deployment: deployment,
        provisioner: provisioner,
        tenant: tenant
      } = context

      test_process = self()

      CreateVolumeRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_volume_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateVolumeRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          driver: driver,
          options: options
        } = data

        assert id == volume_deployment.volume.id
        assert deployment_id == deployment.id
        assert driver == volume_deployment.volume.driver
        assert options == Enum.into(volume_deployment.volume.options, [])

        volume_deployment
        |> Ash.Changeset.for_update(:mark_as_unavailable, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Phoenix.PubSub.subscribe(
        Edgehog.PubSub,
        "ready:volume_deployments:#{volume_deployment.id}"
      )

      Provisioner.start(provisioner)

      assert_receive {:ready, new_volume_deployment}, 1000

      assert new_volume_deployment.id == volume_deployment.id
      assert new_volume_deployment.is_ready

      Phoenix.PubSub.unsubscribe(
        Edgehog.PubSub,
        "ready:volume_deployments:#{volume_deployment.id}"
      )
    end
  end
end
