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

defmodule Edgehog.Files.FileUploadRequest do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.Files.FileUploadRequest.Calculations
  alias Edgehog.Files.FileUploadRequest.Changes
  alias Edgehog.Files.FileUploadRequest.FileSource
  alias Edgehog.Files.FileUploadRequest.ManualActions
  alias Edgehog.Files.FileUploadRequest.Status

  graphql do
    type :file_upload_request

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :file_upload_requests do
        action_types [:create, :update]
      end

      subscribe :file_upload_requests_by_device do
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
      accept [:source, :source_type, :encoding, :progress_tracked, :http_headers]

      argument :device_id, :id do
        allow_nil? false
      end

      change set_attribute(:id, &Ash.UUIDv7.generate/0)

      # We eager check the existence of the device to avoid uploading the file if it doesn't exist
      change manage_relationship(:device_id, :device,
               type: :append,
               eager_validate_with: Edgehog.Devices
             )

      change Changes.SetUploadUrl
      change Changes.SendFileUploadRequest
    end

    create :create_fixture do
      accept [
        :url,
        :source,
        :source_type,
        :encoding,
        :progress_tracked,
        :status,
        :progress_percentage,
        :response_code,
        :response_message,
        :http_headers,
        :device_id
      ]
    end

    update :update_status do
      accept [:status, :progress_percentage, :response_code, :response_message]
    end

    update :set_file_upload_progress do
      accept [:progress_percentage, :status]
    end

    update :set_file_upload_response do
      accept [:status, :response_code, :response_message]
    end

    action :send_file_upload_request do
      argument :file_upload_request, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      run ManualActions.SendFileUploadRequest
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :url, :string do
      allow_nil? false
      public? true
    end

    attribute :source, :string do
      public? true
    end

    attribute :source_type, FileSource do
      public? true

      allow_nil? false
    end

    attribute :encoding, :string do
      public? true

      default ""
    end

    attribute :progress_tracked, :boolean do
      public? true

      default false
    end

    attribute :status, Status do
      public? true

      default :pending
    end

    attribute :progress_percentage, :integer do
      public? true

      constraints min: 0, max: 100
    end

    attribute :response_code, :integer do
      public? true
    end

    attribute :response_message, :string do
      public? true
    end

    attribute :http_headers, :map do
      public? true

      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Edgehog.Devices.Device do
      allow_nil? false
      public? true
      attribute_public? false
    end
  end

  calculations do
    calculate :get_presigned_url, :string do
      public? true

      description "Get a presigned URL for downloading the uploaded file. The URL is valid for a limited time."

      calculation Calculations.GetPresignedUrl
    end
  end

  postgres do
    table "file_upload_requests"
    repo Edgehog.Repo
  end
end
