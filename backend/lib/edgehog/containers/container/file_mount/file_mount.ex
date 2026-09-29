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

defmodule Edgehog.Containers.Container.FileMount do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource],
    notifiers: [Ash.Notifier.PubSub]

  graphql do
    type :container_file_mount
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [
        :mountpoint,
        :required,
        :container_id,
        :default_file_id,
        :file_mode,
        :user_id,
        :group_id
      ]
    ]
  end

  validations do
    validate match(:mountpoint, ~r{^\/(?!.*\/\/)[^\0]*$}) do
      message "must be an absolute path without consecutive slashes"
    end

    validate present(:mountpoint)
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :mountpoint, :string do
      constraints allow_empty?: false

      allow_nil? false
      public? true
    end

    attribute :required, :boolean do
      default true
      allow_nil? false
      public? true
    end

    attribute :file_mode, :integer do
      description "Optional POSIX file mode (decimal representation of octal mode, e.g. 511 for 0777)."
      public? true
      allow_nil? true
    end

    attribute :user_id, :integer do
      description "Optional POSIX user ID (UID) of the file owner."
      public? true
      allow_nil? true
    end

    attribute :group_id, :integer do
      description "Optional POSIX group ID (GID) of the file group."
      public? true
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :container, Edgehog.Containers.Container do
      attribute_type :uuid
      public? true
      allow_nil? false
    end

    belongs_to :default_file, Edgehog.Files.File do
      attribute_type :uuid_v7
      public? true
    end
  end

  identities do
    identity :container_mountpoint, [:container_id, :mountpoint]
  end

  changes do
    change Edgehog.Containers.Container.FileMount.Changes.NormalizeMountpoint
  end

  pub_sub do
    prefix "file_mounts"
    module EdgehogWeb.Endpoint

    publish :create, [[:id, "*"]]
    publish :destroy, [[:id, "*"]]
  end

  postgres do
    table "container_file_mounts"
    repo Edgehog.Repo

    references do
      reference :container, on_delete: :delete
    end
  end
end
