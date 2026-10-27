#
# This file is part of Edgehog.
#
# Copyright 2024 - 2026 SECO Mind Srl
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
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.ImageCredentials.Base64JsonEncoding
  alias Edgehog.Containers.Validations

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

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :image_credentials do
        actions [:create, :update, :destroy]
      end
    end
  end

  actions do
    defaults [:destroy, :read]

    create :create do
      primary? true
      accept [:label, :username, :password]

      validate {Validations.UniquePlainResource,
                keys: [:label], read_action: :plain_image_credentials, field: :label}
    end

    create :copy do
      accept [:label, :username, :password, :source_image_credentials_id]

      upsert? true
      upsert_identity :copied_image_credentials
      upsert_fields []
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:label, :username, :password]

      validate {Validations.UniquePlainResource,
                keys: [:label], read_action: :plain_image_credentials, field: :label}
    end

    read :plain_image_credentials do
      pagination offset?: true, keyset?: true, required?: false

      filter expr(
               is_nil(source_image_credentials_id) and
                 not exists(images.image_deployments, not is_nil(id))
             )
    end

    read :deployed_image_credentials do
      pagination offset?: true, keyset?: true, required?: false

      filter expr(
               not is_nil(source_image_credentials_id) or
                 exists(images.image_deployments, not is_nil(id))
             )
    end

    destroy :destroy_if_dangling do
      description "Destroys the image credentials if they are dangling (copied and not referenced by any image)"

      require_atomic? false
      validate Validations.Dangling
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
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

  relationships do
    belongs_to :source_image_credentials, __MODULE__ do
      attribute_type :uuid
      allow_nil? true
      public? true
    end

    has_many :images, Edgehog.Containers.Image
  end

  calculations do
    calculate :base64_json, :string, Base64JsonEncoding

    calculate :dangling?,
              :boolean,
              expr(not is_nil(source_image_credentials_id) and not exists(images, true))

    calculate :hash,
              :string,
              {Edgehog.Containers.Calculations.Hash, fields: [:label, :username, :password]} do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :copied_image_credentials, [
      :source_image_credentials_id,
      :label,
      :username,
      :password
    ] do
      where expr(not is_nil(source_image_credentials_id))
    end
  end

  postgres do
    table "image_credentials"
    repo Edgehog.Repo
    identity_wheres_to_sql copied_image_credentials: "source_image_credentials_id IS NOT NULL"

    references do
      reference :source_image_credentials, on_delete: :nilify
    end
  end
end
