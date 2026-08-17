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

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.AvailableImages
  alias Edgehog.Astarte.Device.AvailableImages.ImageStatus
  alias Edgehog.Astarte.Device.CreateImageRequest
  alias Edgehog.Config
  alias Edgehog.Containers.Image.Deployment.Provisioner

  describe "Image deployment provisioner" do
    setup do
      tenant = tenant_fixture()
      deployment = deployment_fixture(tenant: tenant, release_opts: [containers: 1])

      timestamp = now()

      opts = %{
        online: true,
        last_connection: timestamp,
        last_disconnection: timestamp
      }

      deployment =
        deployment
        |> Map.get(:device)
        |> Ash.Changeset.for_update(:from_device_status, opts)
        |> Ash.update!(tenant: tenant)
        |> then(&Map.put(deployment, :device, &1))

      [image_deployment] =
        deployment
        |> Ash.load!([container_deployments: [image_deployment: [:image, :device]]],
          tenant: tenant
        )
        |> Map.get(:container_deployments, [])
        |> Enum.map(&Map.get(&1, :image_deployment))

      provisioner =
        Provisioner.start(
          tenant: tenant,
          resource: image_deployment,
          deployment: deployment,
          mode: :manual
        )

      provisioner =
        case provisioner do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      ref = Process.monitor(provisioner)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      %{
        tenant: tenant,
        deployment: deployment,
        image_deployment: image_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      }
    end

    test "timeout/1 returns a bounded timeout that grows with the retries", _context do
      Config
      |> stub(:message_min_timeout!, fn -> 100 end)
      |> stub(:message_max_timeout!, fn -> 1000 end)

      init_timeout = Provisioner.timeout(%{state: :init, retries: 0})
      assert init_timeout >= 0
      assert init_timeout <= 1000

      sent_timeout = Provisioner.timeout(%{state: :sent, retries: 3})
      assert sent_timeout >= 100
      assert sent_timeout <= 1000
    end

    test "sets-up an image on a device", context do
      %{
        image_deployment: image_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
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

        # Update the image deployment to be ready

        image_deployment
        |> Ash.Changeset.for_update(:mark_as_unpulled, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up an image on a device after a retry", context do
      %{
        image_deployment: image_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
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

        image_deployment
        |> Ash.Changeset.for_update(:mark_as_unpulled, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 2000
    end

    test "emits :ready on correct topic on provisioning completion", context do
      %{
        image_deployment: image_deployment,
        deployment: deployment,
        provisioner: provisioner,
        tenant: tenant
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

        image_deployment
        |> Ash.Changeset.for_update(:mark_as_unpulled, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Phoenix.PubSub.subscribe(Edgehog.PubSub, "ready:image_deployments:#{image_deployment.id}")

      Provisioner.run(provisioner)

      assert_receive {:ready, new_image_deployment}, 1000

      assert new_image_deployment.id == image_deployment.id
      assert new_image_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, "ready:image_deployments:#{image_deployment.id}")
    end

    test "doesn't send deployment if it's ready", context do
      %{
        image_deployment: image_deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateImageRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_image_request, 3)

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)

      ready_topic = "ready:image_deployments:#{image_deployment.id}"
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      image_deployment =
        image_deployment
        |> Ash.Changeset.for_update(:mark_as_unpulled, %{})
        |> Ash.update!(tenant: tenant)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
      assert_receive {:ready, new_image_deployment}, 1000

      assert new_image_deployment.id == image_deployment.id
      assert new_image_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "reconciles the state with astarte if a timeout on send is found", context do
      %{
        image_deployment: image_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      # Remove the Pan
      Config
      |> allow(test_process, provisioner)
      |> stub(:message_min_timeout!, fn -> 0 end)

      CreateImageRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_image_request, fn _, _, _ ->
        :ok
      end)

      device_id = image_deployment.device.device_id

      AvailableImages
      |> allow(test_process, provisioner)
      |> expect(:get, fn _client, ^device_id ->
        images = [
          %ImageStatus{id: image_deployment.image.id, pulled: false}
        ]

        {:ok, images}
      end)

      ready_topic = "ready:image_deployments:#{image_deployment.id}"
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 3000
      assert_receive {:ready, new_image_deployment}, 1000

      assert new_image_deployment.id == image_deployment.id
      assert new_image_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "stops if device goes offline", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      timestamp = now()

      CreateImageRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_image_request, fn _, _, _ -> :ok end)

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)
      Provisioner.run(provisioner)

      opts = %{
        online: false,
        last_connection: timestamp,
        last_disconnection: timestamp
      }

      device =
        deployment
        |> Map.get(:device)
        |> Ash.Changeset.for_update(:from_device_status, opts)
        |> Ash.update!(tenant: tenant)

      refute device.online
      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000
    end

    test "immediately stops if device is offline at startup", context do
      %{
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      timestamp = now()

      opts = %{
        online: false,
        last_connection: timestamp,
        last_disconnection: timestamp
      }

      device =
        deployment
        |> Map.get(:device)
        |> Ash.Changeset.for_update(:from_device_status, opts)
        |> Ash.update!(tenant: tenant)

      refute device.online

      test_process = self()

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)

      CreateImageRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_image_request, 3)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000
    end
  end

  defp now, do: DateTime.now!("Etc/UTC")
end
