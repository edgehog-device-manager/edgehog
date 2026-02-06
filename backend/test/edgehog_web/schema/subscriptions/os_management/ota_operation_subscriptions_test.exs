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

defmodule EdgehogWeb.Schema.Subscriptions.OSManagement.OTAOperationSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.OSManagementFixtures

  describe "OTAOperation subscriptions" do
    test "receive data on createManaged", %{socket: socket, tenant: tenant} do
      subscribe(socket, query: created_query())

      ota_operation = managed_ota_operation_fixture(tenant: tenant)

      assert_push "subscription:data", push
      assert_created "otaOperation", ota_operation_data, push

      assert ota_operation_data["id"] == AshGraphql.Resource.encode_relay_id(ota_operation)

      assert ota_operation_data["status"] ==
               ota_operation.status
               |> to_string()
               |> String.upcase()

      assert ota_operation_data["baseImageUrl"] == ota_operation.base_image_url
      assert ota_operation_data["statusProgress"] == ota_operation.status_progress
      assert ota_operation_data["statusCode"] == ota_operation.status_code
      assert ota_operation_data["message"] == ota_operation.message
      assert ota_operation_data["createdAt"] == DateTime.to_iso8601(ota_operation.inserted_at)
      assert ota_operation_data["updatedAt"] == DateTime.to_iso8601(ota_operation.updated_at)
    end

    test "receive data on manual", %{socket: socket, tenant: tenant} do
      subscribe(socket, query: created_query())

      ota_operation = manual_ota_operation_fixture(tenant: tenant)

      assert_push "subscription:data", push
      assert_created "otaOperation", ota_operation_data, push

      assert ota_operation_data["id"] == AshGraphql.Resource.encode_relay_id(ota_operation)

      assert ota_operation_data["status"] ==
               ota_operation.status
               |> to_string()
               |> String.upcase()

      assert ota_operation_data["baseImageUrl"] == ota_operation.base_image_url
      assert ota_operation_data["statusProgress"] == ota_operation.status_progress
      assert ota_operation_data["statusCode"] == ota_operation.status_code
      assert ota_operation_data["message"] == ota_operation.message
      assert ota_operation_data["createdAt"] == DateTime.to_iso8601(ota_operation.inserted_at)
      assert ota_operation_data["updatedAt"] == DateTime.to_iso8601(ota_operation.updated_at)
    end

    test "receive data on updateStatus", %{socket: socket, tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(tenant: tenant)
      subscribe(socket, query: updated_query())

      ota_operation =
        ota_operation
        |> Ash.Changeset.for_update(:update_status, %{status: :success})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push, 500
      assert_updated "otaOperation", ota_operation_data, push

      assert ota_operation_data["id"] == AshGraphql.Resource.encode_relay_id(ota_operation)
      assert ota_operation_data["status"] == "SUCCESS"
      assert ota_operation_data["baseImageUrl"] == ota_operation.base_image_url
      assert ota_operation_data["statusProgress"] == ota_operation.status_progress
      assert ota_operation_data["statusCode"] == ota_operation.status_code
      assert ota_operation_data["message"] == ota_operation.message
      assert ota_operation_data["createdAt"] == DateTime.to_iso8601(ota_operation.inserted_at)
      assert ota_operation_data["updatedAt"] == DateTime.to_iso8601(ota_operation.updated_at)
    end

    test "receive data on markAsTimedOut", %{socket: socket, tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(tenant: tenant, status: :failure)
      subscribe(socket, query: updated_query())

      ota_operation =
        ota_operation
        |> Ash.Changeset.for_update(:mark_as_timed_out, %{})
        |> Ash.update!(tenant: tenant)

      assert_push "subscription:data", push, 500
      assert_updated "otaOperation", ota_operation_data, push

      assert ota_operation_data["id"] == AshGraphql.Resource.encode_relay_id(ota_operation)
      assert ota_operation_data["status"] == "FAILURE"
      assert ota_operation_data["baseImageUrl"] == ota_operation.base_image_url
      assert ota_operation_data["statusProgress"] == ota_operation.status_progress

      assert ota_operation_data["statusCode"] ==
               ota_operation.status_code
               |> to_string()
               |> String.upcase()

      assert ota_operation_data["message"] == ota_operation.message
      assert ota_operation_data["createdAt"] == DateTime.to_iso8601(ota_operation.inserted_at)
      assert ota_operation_data["updatedAt"] == DateTime.to_iso8601(ota_operation.updated_at)
    end

    test "receive data on destroy", %{socket: socket, tenant: tenant} do
      ota_operation = managed_ota_operation_fixture(tenant: tenant)
      subscribe(socket, query: destroyed_query())

      Ash.destroy!(ota_operation, action: :destroy, tenant: tenant)

      assert_push "subscription:data", push
      assert_destroyed("otaOperation", ota_operation_id, push)

      assert ota_operation_id == AshGraphql.Resource.encode_relay_id(ota_operation)
    end
  end

  defp subscribe(socket, opts) do
    query = Keyword.fetch!(opts, :query)

    ref = push_doc(socket, query)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end

  defp created_query do
    """
    subscription {
      otaOperation {
        created {
          id
          status
          baseImageUrl
          statusProgress
          statusCode
          message
          createdAt
          updatedAt
        }
      }
    }
    """
  end

  defp updated_query do
    """
    subscription {
      otaOperation {
        updated {
          id
          status
          baseImageUrl
          statusProgress
          statusCode
          message
          createdAt
          updatedAt
        }
      }
    }
    """
  end

  defp destroyed_query do
    """
    subscription {
      otaOperation {
        destroyed
      }
    }
    """
  end
end
