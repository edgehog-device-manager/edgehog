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

defmodule Edgehog.Containers.Image.Deployment.ProvisionerTest do
  @moduledoc """
  Tests for the image deployment provisioner.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.Image.Deployment.Provisioner
  alias Edgehog.Astarte.Device.CreateImageRequest

  describe "Image deployment provisioner" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

      [image_deployment] =
        deployment
        |> Ash.load!([container_deployments: [image_deployment: :image]], tenant: tenant)
        |> Map.get(:container_deployments, [])
        |> Enum.map(&Map.get(&1, :image_deployment))

      provisioner =
        [
          tenant: tenant,
          image_deployment: image_deployment,
          deployment: deployment,
          mode: :manual
        ]
        |> Provisioner.start_link()
        |> case do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      ref = Process.monitor(provisioner)

      %{
        tenant: tenant,
        deployment: deployment,
        image_deployment: image_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      }
    end

    test "sets-up an image on a device", context do
      %{
        image_deployment: image_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      CreateImageRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_image_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateImageRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          reference: reference
        } = data

        assert id == image_deployment.image.id
        assert deployment_id == deployment.id
        assert reference == image_deployment.image.reference

        message = %Phoenix.Socket.Broadcast{}

        # No need to actually send triggers, we just mimic a message from an
        # image deployment
        Phoenix.PubSub.broadcast(
          Edgehog.PubSub,
          "image_deployments:#{image_deployment.id}",
          message
        )

        :ok
      end)

      Ecto.Adapters.SQL.Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Edgehog.Containers.Image.Deployment.Provisioner.start(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up an image on a device after a retry", context do
      %{
        image_deployment: image_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      CreateImageRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_image_request, fn _, _, _ ->
        {:error, %Astarte.Client.APIError{status: 500, response: "some error message"}}
      end)
      |> expect(:send_create_image_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateImageRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          reference: reference
        } = data

        assert id == image_deployment.image.id
        assert deployment_id == deployment.id
        assert reference == image_deployment.image.reference

        message = %Phoenix.Socket.Broadcast{}

        # No need to actually send triggers, we just mimic a message from an
        # image deployment
        Phoenix.PubSub.broadcast(
          Edgehog.PubSub,
          "image_deployments:#{image_deployment.id}",
          message
        )

        :ok
      end)

      Ecto.Adapters.SQL.Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Edgehog.Containers.Image.Deployment.Provisioner.start(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end
  end
end
