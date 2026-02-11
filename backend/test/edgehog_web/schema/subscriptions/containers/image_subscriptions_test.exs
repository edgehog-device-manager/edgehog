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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.ImageSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  describe "Image subscriptions" do
    test "receive data on image creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      reference = unique_image_reference()
      image = image_fixture(tenant: tenant, reference: reference)

      assert_push "subscription:data", push
      assert_created "image", image_data, push

      assert image_data["id"] == AshGraphql.Resource.encode_relay_id(image)
      assert image_data["reference"] == reference
    end

    test "receive data on image destroy", %{socket: socket, tenant: tenant} do
      image = image_fixture(tenant: tenant)
      subscribe(socket)

      Ash.destroy!(image, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("image", image_id, push)

      assert image_id == AshGraphql.Resource.encode_relay_id(image)
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      image {
        created {
          id
          reference
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
