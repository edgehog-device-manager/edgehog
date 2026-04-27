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
  alias Edgehog.Files.File.FileData

  graphql do
    type :file
  end

  actions do
    defaults [:read]

    create :create do
      description "Creates a new file"
      primary? true

      accept [:name, :size]

      argument :repository_id, :uuid do
        description "The ID of the repository this file will belong to."
        allow_nil? false
      end

      argument :file, Edgehog.Types.Upload do
        description "The file to upload, which will be stored in the bucket."
        allow_nil? false
      end

      change Changes.HandleFileUpload

      change Changes.SetIsArchive

      change manage_relationship(:repository_id, :repository, type: :append)
    end

    create :create_fixture do
      accept [:name, :size, :base_file, :gz_file, :lz4_file, :is_archive]

      argument :repository_id, :uuid do
        allow_nil? false
      end

      change manage_relationship(:repository_id, :repository, type: :append)
    end

    destroy :destroy do
      description "Deletes a file"
      primary? true
      require_atomic? false

      change Changes.HandleFileDeletion
    end

    destroy :destroy_fixture
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      description "Unique name per repository for tracking files"
      allow_nil? false
      public? true
    end

    attribute :size, :integer do
      description "File size in bytes. Sent to device for space reservation."
      allow_nil? false
      public? true
    end

    attribute :is_archive, :boolean do
      description "Used to determine encoding in campaigns"
      allow_nil? false
      public? true
    end

    attribute :base_file, FileData do
      description "The computed url and digest for the base file"
      allow_nil? false
      public? true
    end

    attribute :gz_file, FileData do
      description "The computed url and digest for the gz compressed base file"
      allow_nil? false
      public? true
    end

    attribute :lz4_file, FileData do
      description "The computed url and digest for the lz4 compressed base file"
      allow_nil? false
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

  identities do
    identity :unique_repository_file, [:name, :repository_id]
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
