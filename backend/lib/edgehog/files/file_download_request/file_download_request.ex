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
    extensions: [AshGraphql.Resource]

  alias Edgehog.Files.FileDownloadRequest.Changes
  alias Edgehog.Files.FileDownloadRequest.FileDestination
  alias Edgehog.Files.FileDownloadRequest.ManualActions
  alias Edgehog.Files.FileDownloadRequest.Status

  resource do
    description """
    Represents a request to download a file to a device.

    This resource is used to track the progress and status of file download operations initiated by the system.
    """
  end

  graphql do
    type :file_download_request
  end

  actions do
    defaults [:read]

    create :manual do
      description """
      Initiates an file download request, with a user provided file.
      """

      accept [
        :compression,
        :ttl_seconds,
        :destination,
        :progress
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

      # We eager check the existence of the device to avoid uploading the file if it doesn't exist
      change manage_relationship(:device_id, :device,
               type: :append,
               eager_validate_with: Edgehog.Devices
             )

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
        :compression,
        :ttl_seconds,
        :file_mode,
        :user_id,
        :group_id,
        :destination,
        :progress,
        :status,
        :status_progress,
        :status_code,
        :message,
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
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :url, :string do
      description "The URL from which the file can be downloaded."
      allow_nil? false
      public? true
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
    end

    attribute :compression, :string do
      description "Optional enum string for the file compression with default value empty, other values are: ['tar.gz']"
      public? true

      default ""
    end

    attribute :ttl_seconds, :integer do
      description "Optional ttl for how long to keep the file fore, if 0 is forever, default value is 0."
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

    attribute :destination, FileDestination do
      description "Device-specific field, some default values are storage and streaming."
      public? true

      default "storage"
    end

    attribute :progress, :boolean do
      description "Flag to enable the progress reporting of the download."
      public? true

      default false
    end

    attribute :status, Status do
      description "The status of the file download (e.g., 'pending', 'sent', 'in_progress', 'completed', 'failed')."
      public? true
    end

    attribute :status_progress, :integer do
      description "The progress of the file download as a percentage (0-100)."
      public? true
    end

    attribute :status_code, :integer do
      description "A 0 code is a success, errors are POSIX error numbers."
      public? true
    end

    attribute :message, :string do
      description "Optional message for the response."
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
  end

  postgres do
    table "file_download_requests"
    repo Edgehog.Repo
  end
end
