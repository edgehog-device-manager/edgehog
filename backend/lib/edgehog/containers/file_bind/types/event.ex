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

defmodule Edgehog.Containers.FileBind.Types.Event do
  @moduledoc false
  use AshGraphql.Type

  use Ash.Type.NewType,
    subtype_of: :map,
    constraints: [
      fields: [
        status: [
          type: Edgehog.Containers.FileBind.Types.EventStatus,
          description: "The status value reported by the device for this file bind event.",
          allow_nil?: false
        ],
        message: [
          type: :string,
          description:
            "Additional human-readable context or error details reported with the event.",
          allow_nil?: false
        ],
        add_info: [
          type: {:array, :string},
          description: "Additional information or diagnostic details for the event.",
          allow_nil?: false
        ],
        timestamp: [
          type: :utc_datetime_usec,
          description: "The timestamp when the event was recorded by Astarte."
        ]
      ]
    ]

  @impl AshGraphql.Type
  def graphql_type(_), do: :file_bind_event
end
