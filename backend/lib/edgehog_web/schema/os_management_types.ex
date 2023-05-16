#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.OSManagementTypes do
  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias EdgehogWeb.Resolvers

  @desc """
  Status of the OTA operation.
  """
  enum :ota_operation_status do
    @desc "The OTA operation was created and is waiting an acknowledgment from the device"
    value :pending
    @desc "The OTA operation was acknowledged from the device"
    value :acknowledged
    @desc "The device is downloading the update"
    value :downloading
    @desc "The device is deploying the update"
    value :deploying
    @desc "The device deployed the update"
    value :deployed
    @desc "The device is in the process of rebooting"
    value :rebooting
    @desc "A recoverable error happened during the OTA operation"
    value :error
    @desc "The OTA operation ended with a failure. This is a final state of the OTA Operation"
    value :failure
    @desc "The OTA operation ended successfully. This is a final state of the OTA Operation"
    value :success
  end

  @desc """
  Status code of the OTA operation.
  """
  enum :ota_operation_status_code do
    @desc "The OTA Operation timed out while sending the request to the device"
    value :request_timeout
    @desc "The OTA Operation contained invalid data"
    value :invalid_request
    @desc "An OTA Operation is already in progress on the device"
    value :update_already_in_progress
    @desc "A network error was encountered"
    value :network_error
    @desc "An IO error was encountered"
    value :io_error
    @desc "An internal error was encountered"
    value :internal_error
    @desc "The OTA Operation failed due to an invalid base image"
    value :invalid_base_image
    @desc "A system rollback has occurred"
    value :system_rollback
    @desc "The OTA Operation was canceled"
    value :canceled
  end

  @desc "An OTA update operation"
  node object(:ota_operation) do
    @desc "The URL of the base image being installed on the device"
    field :base_image_url, non_null(:string)

    @desc "The current status of the operation"
    field :status, non_null(:ota_operation_status)

    @desc "The percentage progress [0-100] for the current status"
    field :status_progress, non_null(:integer)

    @desc "The current status code of the operation"
    field :status_code, :ota_operation_status_code

    @desc "A message with additional details about the current status"
    field :message, :string

    @desc "The device targeted from the operation"
    field :device, non_null(:device)

    @desc "The creation timestamp of the operation"
    field :created_at, non_null(:datetime) do
      resolve fn %{inserted_at: timestamp}, _, _ ->
        {:ok, timestamp}
      end
    end

    @desc "The timestamp of the last update to the operation"
    field :updated_at, non_null(:datetime)
  end

  object :os_management_mutations do
    @desc """
    Initiates an OTA update with a user provided OS image
    """
    payload field :create_manual_ota_operation do
      input do
        @desc "The GraphQL ID (not the Astarte Device ID) of the target device"
        field :device_id, non_null(:id)

        @desc """
        An uploaded file of the base image.
        """
        field :base_image_file, :upload
      end

      output do
        @desc "The pending OTA operation"
        field :ota_operation, non_null(:ota_operation)
      end

      middleware Absinthe.Relay.Node.ParseIDs, device_id: :device
      resolve &Resolvers.OSManagement.create_manual_ota_operation/2
    end
  end
end
