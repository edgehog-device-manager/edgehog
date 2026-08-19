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

defmodule Edgehog.Containers.Network.Deployment.ProvisionerTest do
  @moduledoc """
  Tests for the network deployment provisioner.
  """

  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Astarte.Device.AvailableNetworks
  alias Edgehog.Astarte.Device.AvailableNetworks.NetworkStatus
  alias Edgehog.Astarte.Device.CreateNetworkRequest
  alias Edgehog.Config
  alias Edgehog.Containers.Network.Deployment.Provisioner

  describe "Network deployment provisioner" do
    setup do
      tenant = tenant_fixture()
      network = network_fixture(tenant: tenant)

      deployment =
        deployment_fixture(
          tenant: tenant,
          release_opts: [containers: 1, container_params: [networks: [network.id]]]
        )

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

      [network_deployments] =
        deployment
        |> Ash.load!(
          [
            container_deployments: [network_deployments: [network: :options_encoding, device: []]]
          ],
          tenant: tenant
        )
        |> Map.get(:container_deployments, [])
        |> Enum.map(&Map.get(&1, :network_deployments))

      [network_deployment] = network_deployments

      provisioner =
        Provisioner.start(
          tenant: tenant,
          resource: network_deployment,
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
        network_deployment: network_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      }
    end

    test "sets-up a network on a device", context do
      %{
        network_deployment: network_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateNetworkRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_network_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateNetworkRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          driver: driver,
          internal: internal,
          enableIpv6: enable_ipv6,
          options: options
        } = data

        assert id == network_deployment.network.id
        assert deployment_id == deployment.id
        assert driver == network_deployment.network.driver
        assert internal == network_deployment.network.internal
        assert enable_ipv6 == network_deployment.network.enable_ipv6
        assert options == network_deployment.network.options_encoding

        # Update the network deployment to be ready

        network_deployment
        |> Ash.Changeset.for_update(:mark_as_available, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
    end

    test "sets-up a network on a device after a retry", context do
      %{
        network_deployment: network_deployment,
        deployment: deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateNetworkRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_network_request, fn _, _, _ ->
        {:error, %Edgehog.Error.AstarteAPIError{status: 500, response: "some error message"}}
      end)
      |> expect(:send_create_network_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateNetworkRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          driver: driver,
          internal: internal,
          enableIpv6: enable_ipv6,
          options: options
        } = data

        assert id == network_deployment.network.id
        assert deployment_id == deployment.id
        assert driver == network_deployment.network.driver
        assert internal == network_deployment.network.internal
        assert enable_ipv6 == network_deployment.network.enable_ipv6
        assert options == network_deployment.network.options_encoding

        network_deployment
        |> Ash.Changeset.for_update(:mark_as_available, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 2000
    end

    test "emits :ready on correct topic on provisioning completion", context do
      %{
        network_deployment: network_deployment,
        deployment: deployment,
        provisioner: provisioner,
        tenant: tenant
      } = context

      test_process = self()

      CreateNetworkRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_network_request, fn _, _, data ->
        %Edgehog.Astarte.Device.CreateNetworkRequest.RequestData{
          id: id,
          deploymentId: deployment_id,
          driver: driver,
          internal: internal,
          enableIpv6: enable_ipv6,
          options: options
        } = data

        assert id == network_deployment.network.id
        assert deployment_id == deployment.id
        assert driver == network_deployment.network.driver
        assert internal == network_deployment.network.internal
        assert enable_ipv6 == network_deployment.network.enable_ipv6
        assert options == network_deployment.network.options_encoding

        network_deployment
        |> Ash.Changeset.for_update(:mark_as_available, %{})
        |> Ash.update!(tenant: tenant)

        :ok
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Phoenix.PubSub.subscribe(
        Edgehog.PubSub,
        "ready:network_deployments:#{network_deployment.id}"
      )

      Provisioner.run(provisioner)

      assert_receive {:ready, new_network_deployment}, 1000

      assert new_network_deployment.id == network_deployment.id
      assert new_network_deployment.is_ready

      Phoenix.PubSub.unsubscribe(
        Edgehog.PubSub,
        "ready:network_deployments:#{network_deployment.id}"
      )
    end

    test "doesn't send deployment if it's ready", context do
      %{
        network_deployment: network_deployment,
        provisioner: provisioner,
        provisioner_ref: ref,
        tenant: tenant
      } = context

      test_process = self()

      CreateNetworkRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_network_request, 3)

      Sandbox.allow(Edgehog.Repo, test_process, provisioner)

      ready_topic = "ready:network_deployments:#{network_deployment.id}"
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      network_deployment =
        network_deployment
        |> Ash.Changeset.for_update(:mark_as_available, %{})
        |> Ash.update!(tenant: tenant)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000
      assert_receive {:ready, new_network_deployment}, 1000

      assert new_network_deployment.id == network_deployment.id
      assert new_network_deployment.is_ready

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, ready_topic)
    end

    test "reconciles the state with astarte if a timeout on send is found", context do
      %{
        network_deployment: network_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      # Remove the Pan
      Config
      |> allow(test_process, provisioner)
      |> stub(:message_min_timeout!, fn -> 0 end)

      CreateNetworkRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_network_request, fn _, _, _ ->
        :ok
      end)

      device_id = network_deployment.device.device_id

      AvailableNetworks
      |> allow(test_process, provisioner)
      |> expect(:get, fn _client, ^device_id ->
        networks = [
          %NetworkStatus{id: network_deployment.network.id, created: false}
        ]

        {:ok, networks}
      end)

      ready_topic = "ready:network_deployments:#{network_deployment.id}"
      Phoenix.PubSub.subscribe(Edgehog.PubSub, ready_topic)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 3000
      assert_receive {:ready, new_network_deployment}, 1000

      assert new_network_deployment.id == network_deployment.id
      assert new_network_deployment.is_ready

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

      CreateNetworkRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_network_request, fn _, _, _ -> :ok end)

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

      CreateNetworkRequest
      |> allow(test_process, provisioner)
      |> reject(:send_create_network_request, 3)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :device_offline}}, 2000
    end

    test "stops on unsolvable, non-temporary errors", context do
      %{
        network_deployment: network_deployment,
        provisioner: provisioner,
        provisioner_ref: ref
      } = context

      test_process = self()

      topic = Provisioner.Core.topic(network_deployment)

      Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)

      CreateNetworkRequest
      |> allow(test_process, provisioner)
      |> expect(:send_create_network_request, fn _, _, _ ->
        {:error, %Edgehog.Error.AstarteAPIError{status: 400, response: "some error message"}}
      end)

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      Provisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, {:shutdown, :unsolvable_api_error}},
                     2000

      assert_receive {:failure, failed_resource}, 2000
      assert failed_resource.id == network_deployment.id

      Phoenix.PubSub.unsubscribe(Edgehog.PubSub, topic)
    end
  end

  defp now, do: DateTime.now!("Etc/UTC")
end
