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

defmodule Edgehog.Containers.ImageCredentials do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [
      AshGraphql.Resource
    ]

  resource do
    description """
    Contains the credentials used to pull an image from a device.

    Credentials are uniquely identified trough their `:id`, a unique
    `name` field is also provided. The module stores `username` and
    `password`
    """
  end

  graphql do
    type :image_credentials
  end

  actions do
    defaults [:destroy, :read]

    create :create do
      primary? true
      accept [:name, :username, :password]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      public? true
    end

    attribute :username, :string do
      allow_nil? false
      public? true
    end

    attribute :password, :string do
      sensitive? true
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :name, [:name]
  end

  postgres do
    table "image_credentials"
    repo Edgehog.Repo
  end
end
