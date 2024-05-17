#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule Edgehog.Astarte.Cluster do
  use Ash.Resource,
    domain: Edgehog.Astarte,
    data_layer: AshPostgres.DataLayer

  alias Edgehog.Astarte.Cluster

  code_interface do
    define :create
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:base_api_url, :name]
      upsert? true
      upsert_identity :url
      upsert_fields [:updated_at]

      change Cluster.Changes.TrimTrailingSlashFromURL
    end
  end

  attributes do
    integer_primary_key :id

    attribute :base_api_url, :string do
      public? true
      allow_nil? false
    end

    attribute :name, :string do
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :url, [:base_api_url]
  end

  validations do
    validate {Cluster.Validations.URL, attribute: :base_api_url} do
      where changing(:base_api_url)
    end
  end

  postgres do
    table "clusters"
    repo Edgehog.Repo
  end
end
