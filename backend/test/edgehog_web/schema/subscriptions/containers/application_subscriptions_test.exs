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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.ApplicationSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  describe "Application subscriptions" do
    test "receive data on application creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      name = unique_application_name()
      description = unique_application_description()

      application = application_fixture(tenant: tenant, name: name, description: description)

      assert_push "subscription:data", push
      assert_created "application", application_data, push

      assert application_data["id"] == AshGraphql.Resource.encode_relay_id(application)
      assert application_data["name"] == name
      assert application_data["description"] == description
    end

    test "receive data on application update", %{socket: socket, tenant: tenant} do
      application = application_fixture(tenant: tenant)
      subscribe(socket)

      new_name = unique_application_name()

      application =
        application
        |> Ash.Changeset.for_update(:update, %{name: new_name})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push
      assert_updated "application", application_data, push

      assert application_data["id"] == AshGraphql.Resource.encode_relay_id(application)
      assert application_data["name"] == new_name
    end

    test "receive data on application destroy", %{socket: socket, tenant: tenant} do
      application = application_fixture(tenant: tenant)
      subscribe(socket)

      Ash.destroy!(application, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("application", application_id, push)

      assert application_id == AshGraphql.Resource.encode_relay_id(application)
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      application {
        created {
          id
          name
          description
        }
        updated {
          id
          name
          description
        }
        destroyed
      }
    }
    """

    query = Keyword.get(opts, :query, default_query)

    ref = push_doc(socket, query)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end
end
