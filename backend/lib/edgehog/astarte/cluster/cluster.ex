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
    data_layer: AshPostgres.DataLayer

  alias Edgehog.Astarte.Cluster

  code_interface do
    define_for Edgehog.Astarte
    define :create
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      upsert? true
      upsert_identity :url
      upsert_fields [:updated_at]

      change Cluster.Changes.TrimTrailingSlashFromURL
    end
  end

  attributes do
    integer_primary_key :id

    attribute :base_api_url, :string, allow_nil?: false
    attribute :name, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :url, [:base_api_url]
  end

  validations do
    validate {Cluster.Validations.URL, attribute: :base_api_url}
  end

  postgres do
    table "clusters"
    repo Edgehog.Repo
  end
end
