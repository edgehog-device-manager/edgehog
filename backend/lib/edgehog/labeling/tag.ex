#
# This file is part of Edgehog.
#
# Copyright 2022 - 2025 SECO Mind Srl
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

defmodule Edgehog.Labeling.Tag do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Labeling,
    extensions: [
      AshGraphql.Resource
    ]

  require Ash.Query

  resource do
    description """
    A Tag that can be applied to a resource.
    """
  end

  graphql do
    type :tag

    paginate_relationship_with device_tags: :relay
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :name
      accept [:name]
      change {Edgehog.Changes.NormalizeTagName, attribute: :name}
    end

    read :read_assigned_to_devices do
      description "Returns Tags currently assigned to some device."
      prepare build(filter: expr(exists(device_tags, true)))

      pagination do
        required? false
        offset? true
        keyset? true
        countable true
      end
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :device_tags, Edgehog.Labeling.DeviceTag
  end

  identities do
    identity :name, [:name]
  end

  postgres do
    table "tags"
    repo Edgehog.Repo
  end
end
