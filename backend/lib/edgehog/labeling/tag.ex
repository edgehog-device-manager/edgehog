#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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
  use Edgehog.MultitenantResource,
    api: Edgehog.Labeling,
    extensions: [
      AshGraphql.Resource
    ]

  resource do
    description """
    A Tag that can be applied to a resource.
    """
  end

  graphql do
    type :tag

    hide_fields [:tenant]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :name_tenant_id
    end
  end

  attributes do
    integer_primary_key :id

    attribute :name, :string, allow_nil?: false

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :device_tags, Edgehog.Labeling.DeviceTag, private?: true
  end

  identities do
    # These have to be named this way to match the existing unique indexes
    # we already have. Ash uses identities to add a `unique_constraint` to the
    # Ecto changeset, so names have to match. There's no need to explicitly add
    # :tenant_id in the fields because identity in a multitenant resource are
    # automatically scoped to a specific :tenant_id
    # TODO: change index names when we generate migrations at the end of the porting
    identity :name_tenant_id, [:name]
  end

  postgres do
    table "tags"
    repo Edgehog.Repo
  end
end
