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

defmodule Edgehog.Containers.EnvFile do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  alias Edgehog.Containers.Container.Deployment
  alias Edgehog.Containers.EnvFile.Calculations
  alias Edgehog.Containers.EnvFile.Changes
  alias Edgehog.Containers.EnvFile.Validations.NoMultipleTargets
  alias Edgehog.Devices.Device
  alias Edgehog.Files.DeviceFile
  alias Edgehog.Files.FileDownloadRequest

  graphql do
    type :env_file
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:container_deployment_id, :device_id, :file_name, :encoding]

      argument :file_download_request_id, :uuid
      argument :device_file_id, :uuid

      change manage_relationship(:file_download_request_id, :file_download_request, type: :append)

      change manage_relationship(:device_file_id, :device_file, type: :append)

      validate NoMultipleTargets
    end

    create :create_fixture do
      accept [
        :container_deployment_id,
        :file_download_request_id,
        :device_file_id,
        :file_name,
        :uncompressed_file_size_bytes,
        :digest,
        :encoding,
        :uploaded,
        :state
      ]
    end

    update :mark_as_uploaded do
      description """
      Marks the file uploaded through the presigned upload URL as uploaded,
      storing the client-supplied metadata.
      """

      require_atomic? false

      accept [:file_name, :uncompressed_file_size_bytes, :digest, :encoding]

      validate present(:file_name)
      validate present(:digest)

      change set_attribute(:uploaded, true)
    end

    update :link_file_download_request do
      description """
      Links an env file to the file download request created for its uploaded file.
      """

      require_atomic? false

      accept [:file_download_request_id]
    end

    destroy :destroy do
      require_atomic? false
      change Changes.HandleEnvFileDeletion
    end

    destroy :destroy_fixture do
      require_atomic? false
    end

    update :mark_as_sent do
      require_atomic? false
      change set_attribute(:state, :sent)
    end

    update :mark_as_available do
      require_atomic? false
      change set_attribute(:state, :available)
    end

    update :mark_as_unavailable do
      require_atomic? false
      change set_attribute(:state, :unavailable)
    end

    update :mark_as_errored do
      require_atomic? false

      argument :message, :string do
        allow_nil? false
      end

      change set_attribute(:last_message, arg(:message))
      change set_attribute(:state, :error)
    end

    update :set_state do
      require_atomic? false
      accept [:state]
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :file_name, :string do
      description "The name of the file uploaded for a target-less env file."
      public? true
    end

    attribute :uncompressed_file_size_bytes, :integer do
      description "The size of the uploaded file, in bytes, before compression."
      public? true
    end

    attribute :digest, :string do
      description "The digest of the uploaded file, used for integrity verification."
      public? true
    end

    attribute :encoding, :string do
      description "Optional enum string for the file encoding with default value empty, other values are: [gz, lz4, tar, tar.gz, tar.lz4]"
      public? true
    end

    attribute :uploaded, :boolean do
      description "Whether the file for a target-less env file has been uploaded."
      public? true
      allow_nil? false
      default false
    end

    attribute :state, :atom do
      description "The provisioning state of the env file on the device."
      public? true

      constraints one_of: [:created, :sent, :available, :unavailable, :error]
      allow_nil? false
      default :created
    end

    attribute :last_message, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :container_deployment, Deployment do
      attribute_type :uuid
      allow_nil? false
    end

    belongs_to :device, Device do
      allow_nil? false
    end

    belongs_to :file_download_request, FileDownloadRequest do
      attribute_type :uuid_v7
      public? true
    end

    belongs_to :device_file, DeviceFile do
      attribute_type :uuid_v7
      public? true
    end
  end

  calculations do
    calculate :upload_url, :string, Calculations.GetUploadUrl do
      description "Presigned URL the client can use to upload the file for a target-less env file."
      public? true
    end

    calculate :is_ready, :boolean, expr(state in [:available, :unavailable]) do
      public? true
    end
  end

  pub_sub do
    prefix "env_files"
    module EdgehogWeb.Endpoint

    publish :mark_as_sent, [[:id, "*"]]
    publish :mark_as_available, [[:id, "*"]]
    publish :mark_as_unavailable, [[:id, "*"]]
    publish :mark_as_errored, [[:id, "*"]]
    publish :set_state, [[:id, "*"]]
  end

  postgres do
    table "container_deployment_env_files"
    repo Edgehog.Repo

    references do
      reference :container_deployment, on_delete: :delete
      reference :device, on_delete: :delete
    end
  end
end
