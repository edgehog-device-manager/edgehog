#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.ReleaseContainers do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    tenant_id_in_primary_key?: true

  actions do
    defaults [:read, :destroy, create: [:release_id, :container_id]]

    read :releases_by_container do
      argument :container_id, :uuid

      filter expr(container_id == ^arg(:container_id))
    end
  end

  attributes do
    timestamps()
  end

  relationships do
    belongs_to :release, Edgehog.Containers.Release do
      primary_key? true
      allow_nil? false
      attribute_type :uuid
    end

    belongs_to :container, Edgehog.Containers.Container do
      primary_key? true
      allow_nil? false
      attribute_type :uuid
    end
  end

  postgres do
    table "application_release_containers"

    references do
      reference :release, on_delete: :delete
    end
  end
end
