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

defmodule Edgehog.Files.File do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource]

  graphql do
    type :file
  end

  actions do
    defaults [:read, :destroy, create: :*]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :size, :integer do
      allow_nil? false
      public? true
    end

    attribute :digest, :string do
      allow_nil? false
      public? true
    end

    attribute :mode, :integer do
      public? true
    end

    attribute :user_id, :integer do
      public? true
    end

    attribute :group_id, :integer do
      public? true
    end

    attribute :url, :string do
      public? true
    end

    timestamps()
  end

  postgres do
    table "files"
    repo Edgehog.Repo
  end
end
