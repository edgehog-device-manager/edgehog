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

defmodule Edgehog.Audit.Types.ActionEventInfo do
  @moduledoc """
  Type containing all the data regarding an Ash action that triggered the creation
  of an audit event.

  Fields:
  - resource module
  - record id
  - action name
  - action type
  - action inputs (attributes and arguments)
  - attributes changed on the record (includes defaults, auto-generated values, business logic changes...)
  - actor
  """

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        resource_module: [
          type: :module,
          description: "The resource module to which the action belongs to.",
          allow_nil?: false
        ],
        record_id: [
          type: :union,
          description: "The ID of the record targeted by the action.",
          allow_nil?: false,
          constraints: [
            types: [
              integer: [
                type: :integer
              ],
              uuid: [
                type: :uuid
              ]
            ]
          ]
        ],
        action_name: [
          type: :atom,
          description: "Name of the action being executed.",
          allow_nil?: false
        ],
        action_type: [
          type: :atom,
          description: "Type of the action being executed.",
          allow_nil?: false,
          constraints: [
            one_of: [:create, :read, :update, :destroy, :action]
          ]
        ],
        action_inputs: [
          type: :map,
          description: "Input parameters (attributes and arguments) passed to the action.",
          allow_nil?: false
        ],
        changed_attributes: [
          type: :map,
          description: "Attributes changed on the record not present in original inputs.",
          allow_nil?: false
        ],
        actor: [
          type: :map,
          description: "The actor that performed the action.",
          allow_nil?: true
        ]
      ]
    ]

  @type t :: %{
          resource_module: module(),
          record_id: integer() | String.t() | Ash.Union.t(),
          action_name: atom(),
          action_type: :create | :read | :update | :destroy | :action,
          action_inputs: map(),
          changed_attributes: map(),
          actor: map() | nil
        }
end
