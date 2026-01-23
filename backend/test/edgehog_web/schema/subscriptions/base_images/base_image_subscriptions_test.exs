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

defmodule EdgehogWeb.Schema.Subscriptions.BaseImages.BaseImageSubscriptionsTest do
  @moduledoc """
  Tests for subscriptions on base images.
  """
  use EdgehogWeb.SubsCase

  import Edgehog.BaseImagesFixtures

  describe "BaseImage subscriptions" do
    test "receive data on BaseImage creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      base_image = base_image_fixture(tenant: tenant)

      assert_push "subscription:data", push

      assert_created "baseImage", base_image_data, push

      assert base_image_data["id"] == AshGraphql.Resource.encode_relay_id(base_image)
    end

    test "receive data on BaseImage updates", %{socket: socket, tenant: tenant} do
      base_image = base_image_fixture(tenant: tenant)

      base_image_updated_query = """
      subscription {
        baseImage {
          updated {
            id
            starting_version_requirement
          }
        }
      }
      """

      subscribe(socket, query: base_image_updated_query)

      base_image =
        base_image
        |> Ash.Changeset.for_update(:update, %{starting_version_requirement: "0.10.0"})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push

      assert_updated "baseImage", base_image_data, push

      assert base_image_data["id"] == AshGraphql.Resource.encode_relay_id(base_image)
      assert base_image_data["starting_version_requirement"] == "0.10.0"
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      baseImage {
        created {
          id
        }
        updated {
          id
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
