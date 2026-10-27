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

defmodule Edgehog.Containers.Image do
  @moduledoc false
  use Edgehog.MultitenantResource,
    domain: Edgehog.Containers,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Containers.Changes
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.ImageCredentials
  alias Edgehog.Containers.Validations

  # NOTE: regexes from docker ref
  # https://pkg.go.dev/github.com/distribution/reference#pkg-overview
  # The digest regex is scoped to sha256.
  @digest_regex ~r/^sha256:[0-9a-fA-F]{32,}$/
  @tag_regex ~r/^[\w][\w.-]{0,127}$/

  graphql do
    type :image

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :image do
        actions [:create, :destroy]
      end
    end

    paginate_relationship_with devices: :relay
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true

      accept [
        :registry_host,
        :registry_port,
        :repository,
        :image,
        :tag,
        :digest,
        :pull_policy,
        :image_credentials_id
      ]

      validate {Validations.UniquePlainResource,
                keys: [
                  :image_credentials_id,
                  :registry_host,
                  :registry_port,
                  :repository,
                  :image,
                  :tag,
                  :pull_policy,
                  :digest
                ],
                read_action: :plain_images,
                field: :image,
                nils_distinct?: false}
    end

    create :copy do
      accept [
        :registry_host,
        :registry_port,
        :repository,
        :image,
        :tag,
        :digest,
        :pull_policy,
        :image_credentials_id
      ]

      argument :id, :uuid
      argument :credentials, :map

      change set_attribute(:id, arg(:id), set_when_nil?: false)

      change manage_relationship(:credentials,
               on_no_match: {:create, :copy},
               on_lookup: :relate,
               on_match: :ignore
             )
    end

    read :plain_images do
      pagination offset?: true, keyset?: true, required?: false
      filter expr(not exists(image_deployments, true))
    end

    read :deployed_images do
      pagination offset?: true, keyset?: true, required?: false
      filter expr(exists(image_deployments, true))
    end

    destroy :destroy_if_dangling do
      description "Destroys the image if it's dangling (not referenced by any container)"

      require_atomic? false
      validate Validations.Dangling

      change {Changes.MaybeDestroyChildren, children: [:credentials]}
    end
  end

  validations do
    validate present([:tag, :digest], at_most: 1),
      message: "You can either set a tag or the image digest, not both."

    validate match(:tag, @tag_regex),
      where: [present(:tag)],
      message: "Image tag does not match a valid image tag."

    validate match(:digest, @digest_regex),
      where: [present(:digest)],
      message: "Image digest does not match a valid image digest."

    validate present(:registry_host),
      where: [present(:registry_port)],
      message: "must be present when registry_port is set"
  end

  preparations do
    prepare build(load: [:reference])
  end

  attributes do
    uuid_primary_key :id

    attribute :registry_host, :string do
      public? true
    end

    attribute :registry_port, :integer do
      public? true
      constraints min: 1, max: 65_535
    end

    attribute :repository, :string do
      public? true
    end

    attribute :image, :string do
      allow_nil? false
      public? true
    end

    attribute :tag, :string do
      public? true
    end

    attribute :digest, :string do
      public? true
    end

    attribute :pull_policy, Edgehog.Containers.Types.PullPolicy do
      allow_nil? false
      default :if_not_present
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :credentials, ImageCredentials do
      source_attribute :image_credentials_id
      attribute_type :uuid
      public? true
    end

    many_to_many :devices, Edgehog.Devices.Device do
      through Image.Deployment
      join_relationship :image_deployments
      public? true
    end

    has_many :containers, Container do
      public? true
    end

    has_many :image_deployments, Image.Deployment do
      public? false
    end
  end

  calculations do
    calculate :reference, :string, Image.Calculations.Reference do
      allow_nil? false
      public? true
    end

    calculate :dangling?,
              :boolean,
              {Edgehog.Containers.Calculations.Dangling, [parent: :containers]}
  end

  identities do
    identity :reference_credentials,
             [
               :registry_host,
               :registry_port,
               :repository,
               :image,
               :tag,
               :digest,
               :image_credentials_id
             ] do
      nils_distinct? false
    end
  end

  changes do
    change load([:reference]), on: [:create]
  end

  postgres do
    table "images"
    skip_unique_indexes [:reference_credentials]
  end
end
