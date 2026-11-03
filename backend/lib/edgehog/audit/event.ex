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

defmodule Edgehog.Audit.Event do
  @moduledoc """
  Represents an action or change made by a user, to be stored for auditing purposes.
  """
  use Edgehog.MultitenantResource,
    domain: Edgehog.Audit,
    extensions: [AshGraphql.Resource]

  alias Edgehog.Audit.Types

  graphql do
    type :audit_event

    subscriptions do
      pubsub EdgehogWeb.Endpoint

      subscribe :audit_event do
        action_types [:create]
      end
    end
  end

  actions do
    defaults [:read, create: [:message, :log_level, :ash_action_info, :metadata]]

    destroy :destroy do
      primary? true
      public? false
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :message, :string do
      public? true
      allow_nil? false
    end

    attribute :log_level, Types.LogLevel do
      public? true
      allow_nil? false
      default :info
    end

    attribute :ash_action_info, Types.ActionEventInfo do
      public? true
    end

    attribute :metadata, :map do
      public? true
      allow_nil? false
      default %{}
    end

    create_timestamp :inserted_at
  end

  postgres do
    table "audit_events"
  end
end
