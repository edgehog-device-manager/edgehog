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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.DeploymentEventSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  alias Edgehog.Containers.Deployment.Event

  describe "DeploymentEvent subscriptions" do
    test "receive data on deployment event creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      deployment = deployment_fixture(tenant: tenant)

      event =
        Event
        |> Ash.Changeset.for_create(
          :create,
          %{
            deployment_id: deployment.id,
            type: :starting,
            message: "deployment starting",
            add_info: ["some-info"]
          },
          tenant: tenant
        )
        |> Ash.create!()

      assert_push "subscription:data", push
      assert_created "deploymentEvent", event_data, push

      assert event_data["id"] == AshGraphql.Resource.encode_relay_id(event)
      assert event_data["type"] == "STARTING"
      assert event_data["message"] == "deployment starting"
      assert event_data["addInfo"] == ["some-info"]
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      deploymentEvent {
        created {
          id
          type
          message
          addInfo
        }
      }
    }
    """

    query = Keyword.get(opts, :query, default_query)

    ref = push_doc(socket, query)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end
end
