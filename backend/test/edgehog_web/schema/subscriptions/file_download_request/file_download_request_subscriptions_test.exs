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

defmodule EdgehogWeb.Schema.Subscriptions.FileDownloadRequest.FileDownloadRequestSubscriptionsTest do
  @moduledoc false
  use EdgehogWeb.SubsCase

  import Edgehog.FilesFixtures

  alias Edgehog.Files

  describe "FileDownloadRequests subscription" do
    test "receive data on file download request update", %{socket: socket, tenant: tenant} do
      file_download_request = managed_file_download_request_fixture(tenant: tenant)

      subscribe(socket)

      Files.set_response(
        file_download_request,
        [status: :completed, response_code: 0, response_message: "success"],
        tenant: tenant
      )

      assert_push "subscription:data", push

      assert_updated("fileDownloadRequests", file_download_request_data, push)

      assert file_download_request_data["id"] ==
               AshGraphql.Resource.encode_relay_id(file_download_request)

      assert file_download_request_data["status"] == "COMPLETED"
      assert file_download_request_data["response_code"] == 0
      assert file_download_request_data["response_message"] == "success"
    end

    test "receive data on file download request update for a specific device", %{
      socket: socket,
      tenant: tenant
    } do
      file_download_request = managed_file_download_request_fixture(tenant: tenant)

      query = """
      subscription($deviceId: ID!) {
        fileDownloadRequestsByDevice(deviceId: $deviceId){
            updated {
              id
              status,
              progress_percentage,
              response_code,
              response_message,
            }
          }
        }
      """

      subscribe(socket, query: query, variables: %{"deviceId" => file_download_request.device_id})

      Files.set_response(
        file_download_request,
        [status: :completed, response_code: 0, response_message: "success"],
        tenant: tenant
      )

      assert_push "subscription:data", push

      assert_updated("fileDownloadRequestsByDevice", file_download_request_data, push)

      assert file_download_request_data["id"] ==
               AshGraphql.Resource.encode_relay_id(file_download_request)

      assert file_download_request_data["status"] == "COMPLETED"
      assert file_download_request_data["response_code"] == 0
      assert file_download_request_data["response_message"] == "success"
    end

    test "do not receive data on file download request update for a specific device if the device id does not match",
         %{
           socket: socket,
           tenant: tenant
         } do
      file_download_request = managed_file_download_request_fixture(tenant: tenant)

      query = """
      subscription($deviceId: ID!) {
        fileDownloadRequestsByDevice(deviceId: $deviceId){
            updated {
              id
              status,
              progress_percentage,
              response_code,
              response_message,
            }
          }
        }
      """

      subscribe(socket, query: query, variables: %{"deviceId" => Ecto.UUID.generate()})

      Files.set_response(
        file_download_request,
        [status: :completed, response_code: 0, response_message: "success"],
        tenant: tenant
      )

      refute_push "subscription:data", _push
    end

    test "receive data on file download request creation", %{socket: socket, tenant: tenant} do
      subscribe(socket)

      file_download_request =
        managed_file_download_request_fixture(tenant: tenant, status: :pending)

      assert_push "subscription:data", push

      assert_created("fileDownloadRequests", file_download_request_data, push)

      assert file_download_request_data["id"] ==
               AshGraphql.Resource.encode_relay_id(file_download_request)

      assert file_download_request_data["status"] == "PENDING"
    end
  end

  defp subscribe(socket, opts \\ []) do
    default_query = """
    subscription {
      fileDownloadRequests {
        created {
          id
          status
        }
        updated {
          id
          status
          progress_percentage
          response_code
          response_message
        }
      }
    }
    """

    query = Keyword.get(opts, :query, default_query)
    variables = Keyword.get(opts, :variables, %{})

    ref = push_doc(socket, query, variables: variables)
    assert_reply ref, :ok, %{subscriptionId: subscription_id}

    subscription_id
  end
end
