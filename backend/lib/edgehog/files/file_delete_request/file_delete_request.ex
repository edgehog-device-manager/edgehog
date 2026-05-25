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

defmodule Edgehog.Files.FileDeleteRequest do
  @moduledoc false
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource],
    data_layer: AshPostgres.DataLayer

  alias Edgehog.Files.FileDeleteRequest.Changes
  alias Edgehog.Files.FileDeleteRequest.ManualActions
  alias Edgehog.Files.FileDeleteRequest.Status
  alias Edgehog.Files.FileDeleteRequest.Validations

  graphql do
    type :file_delete_request

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :file_delete_requests do
        action_types [:create, :update]
      end

      subscribe :file_delete_requests_by_device do
        action_types [:create, :update]
        read_action :read_by_device
        relay_id_translations device_id: :device
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    read :read_by_device do
      argument :device_id, :id, allow_nil?: false

      get_by :device_id
    end

    create :send_request do
      accept [:force]

      argument :device_id, :id do
        allow_nil? false
      end

      argument :file_download_request_id, :uuid_v7 do
        allow_nil? false
      end

      # Manually generate the ID since it's needed by SendFileDeleteRequest before we hit the DB
      change set_attribute(:id, &Ash.UUIDv7.generate/0)

      validate Validations.SameDevice

      change manage_relationship(:device_id, :device,
               type: :append,
               eager_validate_with: Edgehog.Devices
             ),
             only_when_valid?: true

      change manage_relationship(:file_download_request_id, :file_download_request,
               type: :append,
               eager_validate_with: Edgehog.Files
             ),
             only_when_valid?: true

      change Changes.SendFileDeleteRequest
    end

    create :create_fixture do
      accept [
        :file_download_request_id,
        :force,
        :status,
        :response_code,
        :response_messages,
        :device_id
      ]
    end

    action :send_file_delete_request do
      argument :file_delete_request, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      run ManualActions.SendFileDeleteRequest
    end

    update :set_status do
      accept [:status]
    end

    update :set_response do
      accept [:status, :response_code, :response_messages]
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :force, :boolean do
      description "Force the deletion of the file even if it's currently in use, this could cause errors. Default to false."
      public? true

      default false
    end

    attribute :status, Status do
      public? true

      default :pending
    end

    attribute :response_code, :integer do
      description "Success or error code for the transfer. A 0 code is a success, errors are POSIX errno."
      public? true
    end

    attribute :response_messages, {:array, :string} do
      description "Optional messages for the response"
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Edgehog.Devices.Device do
      description "The device associated with this file delete request."
      allow_nil? false
      public? true
      attribute_public? false
    end

    belongs_to :file_download_request, Edgehog.Files.FileDownloadRequest do
      description "The file download request that resulted in the file targeted by this delete request"
      allow_nil? false
      public? true
      attribute_type :uuid_v7
      attribute_public? false
    end
  end

  postgres do
    table "file_delete_requests"
    repo Edgehog.Repo
  end
end
