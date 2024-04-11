#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule Edgehog.Labeling.DeviceTag do
  use Edgehog.MultitenantResource,
    domain: Edgehog.Labeling,
    tenant_id_in_primary_key?: true

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true

      accept [:tag_id, :device_id]
    end

    update :update do
      primary? true

      accept [:tag_id, :device_id]
    end
  end

  relationships do
    belongs_to :tag, Edgehog.Labeling.Tag do
      allow_nil? false
      primary_key? true
    end

    belongs_to :device, Edgehog.Devices.Device do
      allow_nil? false
      primary_key? true
    end
  end

  identities do
    # These have to be named this way to match the existing unique indexes
    # we already have. Ash uses identities to add a `unique_constraint` to the
    # Ecto changeset, so names have to match. There's no need to explicitly add
    # :tenant_id in the fields because identity in a multitenant resource are
    # automatically scoped to a specific :tenant_id
    # TODO: change index names when we generate migrations at the end of the porting
    identity :tag_id_tenant_id, [:tag_id]
    identity :device_id_tenant_id, [:device_id]
  end

  postgres do
    table "devices_tags"
    repo Edgehog.Repo

    references do
      reference :device, on_delete: :delete
      reference :tag, on_delete: :delete
    end
  end
end
