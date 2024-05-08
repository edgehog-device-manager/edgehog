#
# This file is part of Edgehog.
#
# Copyright 2023-2024 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.UpdateChannel do
  use Edgehog.MultitenantResource,
    domain: Edgehog.UpdateCampaigns,
    extensions: [
      AshGraphql.Resource
    ]

  resource do
    description """
    Represents an UpdateChannel.

    An UpdateChannel represents a set of device groups that can be targeted in \
    an UpdateCampaign.
    """
  end

  graphql do
    type :update_channel
  end

  validations do
    validate Edgehog.Validations.slug(:handle) do
      where changing(:handle)
    end
  end

  attributes do
    integer_primary_key :id

    attribute :handle, :string do
      description """
      The identifier of the update channel.

      It should start with a lower case ASCII letter and only contain \
      lower case ASCII letters, digits and the hyphen - symbol.
      """

      public? true
      allow_nil? false
    end

    attribute :name, :string do
      description "The display name of the update channel."
      public? true
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    # These have to be named this way to match the existing unique indexes
    # we already have. Ash uses identities to add a `unique_constraint` to the
    # Ecto changeset, so names have to match. There's no need to explicitly add
    # :tenant_id in the fields because identity in a multitenant resource are
    # automatically scoped to a specific :tenant_id
    # TODO: change index names when we generate migrations at the end of the porting
    identity :handle_tenant_id, [:handle]
    identity :name_tenant_id, [:name]
  end

  postgres do
    table "update_channels"
    repo Edgehog.Repo
  end
end
