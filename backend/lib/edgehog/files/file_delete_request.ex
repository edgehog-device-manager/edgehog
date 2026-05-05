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

defmodule Edgehog.Files.FileDeleteRequest do
  use Ash.Resource,
    otp_app: :edgehog,
    domain: Edgehog.Files,
    extensions: [AshGraphql.Resource],
    data_layer: AshPostgres.DataLayer

  graphql do
    type :file_delete_request
  end

  actions do
    defaults [:read, :destroy]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :file_id, :string do
      allow_nil? false
      public? true
    end

    attribute :force, :boolean do
      public? true
    end

    attribute :status, :string do
      public? true
    end

    attribute :response_code, :integer do
      public? true
    end

    attribute :response_messages, :string do
      public? true
    end

    timestamps()
  end

  postgres do
    table "file_delete_requests"
    repo Edgehog.Repo
  end
end
