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

defmodule Edgehog.Files.FileDownloadRequest do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.Files.FileDownloadRequest.Changes
  alias Edgehog.Files.FileDownloadRequest.FileDestination
  alias Edgehog.Files.FileDownloadRequest.ManualActions
  alias Edgehog.Files.FileDownloadRequest.Status
  alias Edgehog.Files.FileDownloadRequest.Validations

  resource do
    description """
    Represents a request to download a file to a device.

    This resource is used to track the progress and status of file download operations initiated by the system.
    """
  end

  graphql do
    type :file_download_request

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :file_download_requests do
        action_types [:create, :update]
      end

      subscribe :file_download_requests_by_device do
        action_types [:create, :update]
        read_action :read_by_device
        relay_id_translations device_id: :device
      end
    end
  end

  actions do
    defaults [:read]

    read :read_by_device do
      argument :device_id, :id, allow_nil?: false

      get_by :device_id
    end

    create :managed do
      accept [
        :ttl_seconds,
        :file_mode,
        :user_id,
        :group_id,
        :destination_type,
        :destination,
        :progress_tracked
      ]

      argument :file_id, :uuid do
        description "The ID identifying the File for which we are creating the download request."
        allow_nil? false
      end

      argument :device_id, :id do
        description "The ID identifying the Device the File Download Request will be sent to"
        allow_nil? false
      end

      # Manually generate the ID since it's needed by HandleFileUpload before we hit the DB
      change set_attribute(:id, &Ash.UUIDv7.generate/0)

      # We eager check the existence of the device to avoid uploading the file if it doesn't exist
      change manage_relationship(:device_id, :device,
               type: :append,
               eager_validate_with: Edgehog.Devices
             )

      validate Validations.FileExists

      change Changes.ExtractFileData, only_when_valid?: true
      change Changes.SendFileDownloadRequest
    end

    create :manual do
      description """
      Initiates an file download request, with a user provided file.
      """

      accept [
        :file_name,
        :uncompressed_file_size_bytes,
        :encoding,
        :ttl_seconds,
        :file_mode,
        :user_id,
        :group_id,
        :destination_type,
        :destination,
        :progress_tracked
      ]

      argument :device_id, :id do
        description "The ID identifying the Device the File Download Request will be sent to"
        allow_nil? false
      end

      argument :file, Edgehog.Types.Upload do
        description "The file, which will be uploaded to the storage."
      end

      # Manually generate the ID since it's needed by HandleFileUpload before we hit the DB
      change set_attribute(:id, &Ash.UUIDv7.generate/0)

      validate Validations.CheckEncoding

      change manage_relationship(:device_id, :device, type: :append),
        only_when_valid?: true

      change set_attribute(:manual?, true)
      change Changes.HandleEphemeralFileUpload
      change Changes.SendFileDownloadRequest
    end

    create :create_fixture do
      accept [
        :url,
        :file_name,
        :uncompressed_file_size_bytes,
        :digest,
        :encoding,
        :ttl_seconds,
        :file_mode,
        :user_id,
        :group_id,
        :destination_type,
        :destination,
        :progress_tracked,
        :status,
        :progress_percentage,
        :response_code,
        :response_message,
        :device_id,
        :manual?
      ]
    end

    destroy :destroy do
      require_atomic? false

      change Changes.HandleEphemeralFileDeletion do
        where attribute_equals(:manual?, true)
      end
    end

    destroy :destroy_fixture do
      require_atomic? false
    end

    action :send_file_download_request do
      argument :file_download_request, :struct do
        constraints instance_of: __MODULE__
        allow_nil? false
      end

      run ManualActions.SendFileDownloadRequest
    end

    update :set_path_on_device do
      argument :path_on_device, :string, allow_nil?: false

      change set_attribute(:path_on_device, arg(:path_on_device))
    end

    update :set_size_bytes do
      argument :decompressed_file_size_bytes, :integer, allow_nil?: false

      change set_attribute(:uncompressed_file_size_bytes, arg(:decompressed_file_size_bytes))
    end

    update :set_response do
      accept [:status, :progress_percentage, :response_code, :response_message]

      # Needed because and HandleEphemeralFileDeletion are not atomic
      require_atomic? false

      # After file download request is finished remove data from bucket
      change Changes.HandleEphemeralFileDeletion do
        where [attribute_equals(:manual?, true)]
      end
    end

    update :set_progress do
      accept [:progress_percentage, :status]
    end

    update :set_status do
      accept [:status]
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :url, :string do
      description "The URL from which the file can be downloaded."
      public? true

      allow_nil? false
    end

    attribute :file_name, :string do
      description "The name of the file being downloaded."
      public? true
    end

    attribute :uncompressed_file_size_bytes, :integer do
      description "The size of the file being downloaded, in bytes, before compression."
      public? true
    end

    attribute :digest, :string do
      description "The digest of the file being downloaded, used for integrity verification."
      public? true

      allow_nil? false
    end

    attribute :encoding, :string do
      description "Optional enum string for the file encoding with default value empty, other values are: [gz, lz4, tar, tar.gz, tar.lz4]"
      public? true

      default ""
    end

    attribute :ttl_seconds, :integer do
      description "Optional ttl for how long to keep the file for, if 0 is forever, default value is 0."
      public? true

      default 0
    end

    attribute :file_mode, :integer do
      description "Optional unix mode for the file, set to default if 0. All files are immutable, so setting it to writable has no effect."
      public? true

      default 0
    end

    attribute :user_id, :integer do
      description "Optional unix uid of the user owning the file, set to default if -1."
      public? true

      default -1
    end

    attribute :group_id, :integer do
      description "Optional unix gid of the group owning the file, set to default if -1."
      public? true

      default -1
    end

    attribute :destination_type, FileDestination do
      description "Device-specific field, supported values are storage, streaming and filesystem."
      public? true

      allow_nil? false
    end

    attribute :destination, :string do
      description "Destination-specific information on where to write the file to, when the destination_type is :filesystem"
      public? true
    end

    attribute :path_on_device, :string do
      description "Set by the device, represents the path where the file was stored when destination_type is :storage"
      public? true
    end

    attribute :progress_tracked, :boolean do
      description "Flag to enable the progress reporting of the download."
      public? true

      default false
    end

    attribute :status, Status do
      description "The status of the file download (e.g., 'pending', 'sent', 'in_progress', 'completed', 'failed')."
      public? true

      default :pending
    end

    attribute :progress_percentage, :integer do
      description "The progress of the file download as a percentage (0-100)."
      public? true

      constraints min: 0, max: 100
    end

    attribute :response_code, :integer do
      description "A 0 code is a success, errors are POSIX error numbers."
      public? true
    end

    attribute :response_message, :string do
      description "Optional message for the response sent by the device."
      public? true
    end

    attribute :manual?, :boolean do
      description "Flag to indicate if the file download request was initiated manually by a user."
      source :is_manual
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Edgehog.Devices.Device do
      description "The device associated with this file download request."
      allow_nil? false
      public? true
      attribute_public? false
    end

    has_one :campaign_target, Edgehog.Campaigns.CampaignTarget do
      description """
      The campaign target that created the file download request, if any.
      """

      public? true
    end
  end

  pub_sub do
    prefix "file_download_requests"
    module EdgehogWeb.Endpoint

    publish :managed, [[:id, "*"]]
    publish :manual, [[:id, "*"]]

    publish :set_response, [[:id, "*"]]
  end

  postgres do
    table "file_download_requests"
    repo Edgehog.Repo
  end
end
