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

defmodule Edgehog.Files.File do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Files.File.Changes

  graphql do
    type :file
  end

  actions do
    defaults [:read]

    create :create do
      description "Create a new file by uploading it to the storage."
      primary? true

      accept [:name, :mode, :user_id, :group_id]

      argument :repository_id, :uuid do
        description "The ID of the repository this file will belong to."
        allow_nil? false
      end

      argument :file, Edgehog.Types.Upload do
        description "The file to upload, which will be stored in the bucket."
        allow_nil? false
      end

      change Changes.HandleFileUpload

      change manage_relationship(:repository_id, :repository, type: :append)
    end

    create :create_fixture do
      accept [:name, :size, :digest, :mode, :user_id, :group_id, :url]

      argument :repository_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:repository_id, :repository, type: :append)
    end

    destroy :destroy do
      description "Deletes a file and its stored content."
      primary? true

      # Needed because HandleFileDeletion is not atomic
      require_atomic? false

      change Changes.HandleFileDeletion
    end

    destroy :destroy_fixture
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      description "Filename for display and as default name on the device."
      allow_nil? false
      public? true
    end

    attribute :size, :integer do
      description "File size in bytes. Sent to device for space reservation."
      allow_nil? false
      public? true
    end

    attribute :digest, :string do
      description "File digest in format algorithm:hash (e.g., sha256:abc123) for integrity checks."
      allow_nil? false
      public? true
    end

    attribute :mode, :integer do
      description "Unix file mode (e.g., 0o644). Applied when file is stored on device."
      public? true
      # Read/Write for owner, Read for group/others
      default 0o644
    end

    attribute :user_id, :integer do
      description "Unix UID for file ownership on the device."
      public? true
      # root
      default 0
    end

    attribute :group_id, :integer do
      description "Unix GID for file ownership on the device."
      public? true
      # root
      default 0
    end

    attribute :url, :string do
      description "Full URL where file is stored. Set by the uploader."
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :repository, Edgehog.Files.Repository do
      description "The repository this file belongs to."
      public? true
      attribute_public? false
      attribute_type :uuid
      allow_nil? false
    end
  end

  postgres do
    table "files"
    repo Edgehog.Repo

    references do
      reference :repository,
        on_delete: :delete,
        match_with: [tenant_id: :tenant_id],
        match_type: :simple
    end
  end
end
