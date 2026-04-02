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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.DeploymentSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  describe "Deployment subscriptions" do
    test "receive data on deployment creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      deployment = deployment_fixture(tenant: tenant)

      assert_push "subscription:data", push
      assert_created "deployment", deployment_data, push

      assert deployment_data["id"] == AshGraphql.Resource.encode_relay_id(deployment)
      assert deployment_data["state"] == "PENDING"
    end

    test "receive data on deployment update", %{socket: socket, tenant: tenant} do
      deployment = deployment_fixture(tenant: tenant)
      subscribe(socket)

      deployment =
        deployment
        |> Ash.Changeset.for_update(:set_state, %{state: :started})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push
      assert_updated("deployment", deployment_data, push)

      assert deployment_data["id"] == AshGraphql.Resource.encode_relay_id(deployment)
      assert deployment_data["state"] == "STARTED"
    end

    test "receive data on deployment destroy", %{socket: socket, tenant: tenant} do
      deployment = deployment_fixture(tenant: tenant)
      subscribe(socket)

      Ash.destroy!(deployment, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("deployment", deployment_id, push)

      assert deployment_id == AshGraphql.Resource.encode_relay_id(deployment)
    end

    test "receive data on deployment update for a specific deployment", %{
      socket: socket,
      tenant: tenant
    } do
      deployment = deployment_fixture(tenant: tenant)

      subscribe(socket,
        query: deployment_by_id_updated_query(),
        variables: %{"deploymentId" => deployment.id}
      )

      deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :started})
      |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push
      assert_updated("deploymentById", deployment_data, push)

      assert deployment_data["id"] == AshGraphql.Resource.encode_relay_id(deployment)
      assert deployment_data["state"] == "STARTED"
    end

    test "do not receive data on deployment update for a different deployment id", %{
      socket: socket,
      tenant: tenant
    } do
      deployment = deployment_fixture(tenant: tenant)

      subscribe(socket,
        query: deployment_by_id_updated_query(),
        variables: %{"deploymentId" => Ecto.UUID.generate()}
      )

      deployment
      |> Ash.Changeset.for_update(:set_state, %{state: :started})
      |> Ash.update!(tenant: tenant)

      refute_push "subscription:data", _push
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      deployment {
        created {
          id
          state
        }
        updated {
          id
          state
        }
        destroyed
      }
    }
    """

    query = Keyword.get(opts, :query, default_query)
    variables = Keyword.get(opts, :variables, %{})

    ref = push_doc(socket, query, variables: variables)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end

  defp deployment_by_id_updated_query do
    """
    subscription($deploymentId: ID!) {
      deploymentById(deploymentId: $deploymentId) {
        updated {
          id
          state
        }
      }
    }
    """
  end
end
