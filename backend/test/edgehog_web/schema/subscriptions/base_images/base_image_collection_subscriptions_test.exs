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

defmodule EdgehogWeb.Schema.Subscriptions.BaseImages.BaseImageCollectionSubscriptionsTest do
  @moduledoc """
  Tests for subscriptions on base images.
  """
  use EdgehogWeb.SubsCase

  import Edgehog.BaseImagesFixtures

  describe "BaseImageCollection subscriptions" do
    test "receive data on BaseImageCollection creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      base_image_collection = base_image_collection_fixture(tenant: tenant)

      assert_push "subscription:data", push

      assert_created "baseImageCollection", base_image_collection_data, push

      assert base_image_collection_data["id"] ==
               AshGraphql.Resource.encode_relay_id(base_image_collection)
    end

    test "receive data on BaseImageCollection updates", %{socket: socket, tenant: tenant} do
      base_image_collection = base_image_collection_fixture(tenant: tenant)

      base_image_collection_updated_query = """
      subscription {
        baseImageCollection {
          updated {
            id
            name
          }
        }
      }
      """

      subscribe(socket, query: base_image_collection_updated_query)

      base_image_collection =
        base_image_collection
        |> Ash.Changeset.for_update(:update, %{name: "thename"})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push

      assert_updated "baseImageCollection", base_image_collection_data, push

      assert base_image_collection_data["id"] ==
               AshGraphql.Resource.encode_relay_id(base_image_collection)

      assert base_image_collection_data["name"] == "thename"
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      baseImageCollection {
        created {
          id
        }
        updated {
          id
          name
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
