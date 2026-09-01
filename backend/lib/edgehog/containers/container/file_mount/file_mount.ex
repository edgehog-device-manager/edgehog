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
    defaults [:read, :destroy, create: [:mountpoint, :required, :container_id, :default_file_id]]
  end

  validations do
    validate match(:mountpoint, ~r{^/})
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
