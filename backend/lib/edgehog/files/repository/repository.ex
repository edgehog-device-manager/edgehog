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

defmodule Edgehog.Files.Repository do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Validations

  resource do
    description """
    A logical collection of files.

    Repositories provide organization for files, similar to how
    BaseImageCollections group BaseImages. Storage location is
    configured at the application level, not per-repository.
    """
  end

  graphql do
    type :repository

    paginate_relationship_with files: :relay
  end

  actions do
    defaults [:read]

    create :create do
      description "Creates a new repository."
      primary? true

      accept [:name, :handle, :description]
    end

    create :create_fixture do
      accept [:name, :handle, :description]
    end

    update :update do
      description "Updates a repository."
      primary? true

      accept [:name, :handle, :description]
    end

    destroy :destroy do
      description "Deletes a repository"
      primary? true
    end

    destroy :destroy_fixture
  end

  validations do
    validate Validations.handle(:handle) do
      where changing(:handle)
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      description "The display name of the repository."
      allow_nil? false
      public? true
    end

    attribute :handle, :string do
      description """
      The identifier of the repository.

      It should start with a lower case ASCII letter and only contain \
      lower case ASCII letters, digits and the hyphen - symbol.
      """

      allow_nil? false
      public? true
    end

    attribute :description, :string do
      description "An optional description of the repository."
      public? true
    end

    timestamps()
  end

  relationships do
    has_many :files, Edgehog.Files.File do
      description "The files associated with the repository."
      public? true
    end
  end

  identities do
    identity :name, [:name]
    identity :handle, [:handle]
  end

  postgres do
    table "repositories"
    repo Edgehog.Repo
  end
end
