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

defmodule EdgehogWeb.Schema.Subscriptions.Containers.ImageCredentialsSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.ContainersFixtures

  describe "ImageCredentials subscriptions" do
    test "receive data on image credentials creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      image_credentials = image_credentials_fixture(tenant: tenant)

      assert_push "subscription:data", push

      assert_created "imageCredentials", image_credentials_data, push

      assert image_credentials_data["id"] ==
               AshGraphql.Resource.encode_relay_id(image_credentials)

      assert image_credentials_data["label"] == image_credentials.label
      assert image_credentials_data["username"] == image_credentials.username
    end

    test "receive data on image credentials destroy", %{socket: socket, tenant: tenant} do
      image_credentials = image_credentials_fixture(tenant: tenant)
      subscribe(socket)

      Ash.destroy!(image_credentials, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("imageCredentials", image_credentials_id, push)

      assert image_credentials_id == AshGraphql.Resource.encode_relay_id(image_credentials)
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      imageCredentials {
        created {
          id
          label
          username
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
