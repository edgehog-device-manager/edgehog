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

defmodule Edgehog.Actors.Actor do
  @moduledoc """
  Edgheog Actors.
  This module represents an actor performing a call trough the GraphQL APIs.
  It implements the ID Token from the OpenID Connect spec.
  """

  use Ash.Resource,
    domain: Edgehog.Actors,
    data_layer: :embedded

  resource do
    require_primary_key? false
  end

  actions do
    defaults [:read]

    create :from_claims do
      accept [
        :sub,
        :aud,
        :exp,
        :iat,
        :auth_time,
        :preferred_username,
        :email,
        :given_name,
        :family_name,
        :claims
      ]
    end
  end

  attributes do
    # TODO: consider using issuer claim
    # Not required in our use-case for now

    attribute :sub, :string do
      description """
        Subject Identifier, a unique and never reassigned identifier within the Issuer for the user.
        Only at most 255 ASCII characters are allowed. For example, the user's Keycloak UUID
      """
    end

    attribute :aud, :string do
      description """
        The OAuth2 `client_id` of the of the Client requesting auth on behalf of the user
      """
    end

    attribute :exp, :datetime do
      description """
        Expiration time of the token (JWT) corresponding to the current actor
      """
    end

    attribute :iat, :datetime do
      description """
        Time at which the token (JWT) corresponding to the current actor was issued at
      """
    end

    attribute :auth_time, :datetime do
      description """
        Time at which the user authentication occurred
      """
    end

    attribute :preferred_username, :string do
      description """
        Username of the user represented by the current actor
      """
    end

    attribute :email, :string do
      description """
        Email connected to the user's ID
      """
    end

    attribute :given_name, :string do
      description """
        Given name of the user
      """
    end

    attribute :family_name, :string do
      description """
        Family name of the user
      """
    end

    attribute :claims, :map do
      description """
        DEPRECATED: claims specified as a map are deprecated, and will be dropped once
        the new authentication/authorization flow is finalized
      """
    end
  end
end
