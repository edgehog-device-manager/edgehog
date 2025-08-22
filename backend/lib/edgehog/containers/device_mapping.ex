#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.DeviceMapping do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Container

  graphql do
    type :device_mapping
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:path_on_host, :path_in_container, :cgroup_permissions],
      update: [:path_on_host, :path_in_container, :cgroup_permissions]
    ]
  end

  attributes do
    uuid_primary_key :id

    attribute :path_on_host, :string do
      public? true
      allow_nil? false
    end

    attribute :path_in_container, :string do
      public? true
      allow_nil? false
    end

    attribute :cgroup_permissions, :string do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :container, Container do
      source_attribute :container_id
      attribute_type :uuid
      public? true
    end
  end

  postgres do
    table "device_mappings"
    repo Edgehog.Repo
  end
end
