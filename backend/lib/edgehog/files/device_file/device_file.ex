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

defmodule Edgehog.Files.DeviceFile do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Devices

  graphql do
    type :device_file

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :device_files do
        action_types [:create, :update]
      end

      subscribe :device_files_by_device do
        action_types [:create, :update, :destroy]
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

    create :create do
      accept [:file_id, :path_on_device, :size_bytes]

      argument :device_id, :id do
        allow_nil? false
      end

      argument :file_download_request_id, :uuid

      change manage_relationship(:device_id, :device,
               type: :append,
               eager_validate_with: Devices
             ),
             only_when_valid?: true

      change manage_relationship(:file_download_request_id, :file_download_request,
               on_lookup: :relate,
               on_no_match: :ignore,
               on_missing: :ignore
             ),
             only_when_valid?: true
    end

    create :create_fixture do
      accept [
        :file_id,
        :path_on_device,
        :size_bytes,
        :deleted,
        :device_id
      ]
    end

    update :set_path_on_device do
      accept [:path_on_device]
    end

    update :set_size_bytes do
      accept [:size_bytes]
    end

    update :set_deleted do
      change set_attribute(:deleted, true)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :file_id, :string do
      description "The identifier of the file stored on the device."
      allow_nil? false
      public? true
    end

    attribute :path_on_device, :string do
      description "The path where the device stored the file."
      public? true
    end

    attribute :size_bytes, :integer do
      description "The size of the file stored on the device, in bytes."
      public? true
    end

    attribute :deleted, :boolean do
      description "Whether the file transferred with this request was deleted from the device"
      public? true

      default false
    end

    timestamps()
  end

  relationships do
    belongs_to :device, Edgehog.Devices.Device do
      description "The device the file belongs to."
      allow_nil? false
      public? true
      attribute_public? false
    end

    belongs_to :file_download_request, Edgehog.Files.FileDownloadRequest do
      description "The file download request associated with the file, if any."
      public? true
      attribute_public? false
      attribute_type :uuid_v7
    end
  end

  identities do
    identity :file_id, [:file_id]
  end

  postgres do
    table "device_files"
    repo Edgehog.Repo
  end
end
