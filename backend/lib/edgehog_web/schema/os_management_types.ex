#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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
    @desc "The OTA operation was accepted from the device"
    value :in_progress
    @desc "The OTA operation ended with an error"
    value :error
    @desc "The OTA operation ended succesfully"
    value :done
  end

  @desc "An OTA update operation"
  node object(:ota_operation) do
    @desc "The URL of the base image being installed on the device"
    field :base_image_url, non_null(:string)

    @desc "The current status of the operation"
    field :status, non_null(:ota_operation_status)

    @desc "The current status code of the operation"
    field :status_code, :string

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
