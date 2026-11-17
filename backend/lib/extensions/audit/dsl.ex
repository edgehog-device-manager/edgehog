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

defmodule Ash.Audit do
  @moduledoc """
  An Ash auditing plugin.

  This extension allows to setup audit events on a resource:

  -  `Ash.Audit.Transformers.ResolveConfiguration` resolves the actions to include
       and exclude, based on the configuration
  -  `Ash.Audit.Transformers.ApplyConfiguration`:
       - for create, update, destroy, adds a change at the beginning of the action
         that calls `Edgehog.Audit.AuditService` to register the event
       - for manual actions, it does the same through a preparation

  The event contains the actor only if the extension is configured to do so.

  ## Example

  ```elixir
  audit_log do
    included_action_types [:create, :update, :destroy]
    excluded_action_types [:action]
    included_actions [:admin_read, :admin_action]
    excluded_actions [:fixture_create]
  end
  ```
  """

  alias Ash.Audit.Transformers

  @audit_log %Spark.Dsl.Section{
    name: :audit_log,
    describe: """
    Configures what is audited on the resource.
    """,
    schema: [
      included_action_types: [
        # maybe make them entities?
        type: {:list, :atom},
        default: [:audit_all_action_types],
        doc:
          "Whitelist of action types that should be included in the audit logs. Defaults to all the supported types."
      ],
      included_actions: [
        type: {:list, :atom},
        default: [:audit_all_actions],
        doc:
          "Whitelist for the actions that should be included in the audit logs. Defaults to all the supported actions."
      ],
      excluded_action_types: [
        type: {:list, :atom},
        default: [],
        doc:
          "Blacklist for the action types that should not be included in the audit logs. Defaults to none."
      ],
      excluded_actions: [
        type: {:list, :atom},
        default: [],
        doc:
          "Blacklist for the actions that should not be included in the audit logs. Defaults to none."
      ],
      actor?: [
        type: :boolean,
        default: true,
        doc: "Whether to store the actor or not when possible."
      ]
    ],
    entities: []
  }

  # credo:disable-for-next-line
  use Spark.Dsl.Extension,
    transformers: [Transformers.ResolveConfiguration, Transformers.ApplyConfiguration],
    sections: [@audit_log]
end

defmodule Ash.Audit.Info do
  @moduledoc """
  Utility functions.

  They can return various information about the `audit_log` configuration section of a resource.
  """

  use Spark.InfoGenerator, extension: Ash.Audit, sections: [@audit_log]
  alias Spark.Dsl.Extension

  def actor?(dsl_state) do
    Extension.get_opt(dsl_state, [:audit_log], :actor?, true)
  end

  def included_action_types(dsl_state) do
    Extension.get_opt(dsl_state, [:audit_log], :included_action_types, [:audit_all_action_types])
  end

  def included_actions(dsl_state) do
    Extension.get_opt(dsl_state, [:audit_log], :included_actions, [:audit_all_actions])
  end

  def excluded_action_types(dsl_state) do
    Extension.get_opt(dsl_state, [:audit_log], :excluded_action_types, [])
  end

  def excluded_actions(dsl_state) do
    Extension.get_opt(dsl_state, [:audit_log], :excluded_actions, [])
  end
end
