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

defmodule Ash.Astarte.Triggers.Resource do
  @moduledoc """
  The triggers resource DSL.

  This extension adds two entries for resources handling triggers:

  - Handlers: specifying how incoming triggers should be handled.
    Example:
    ```elixir
    handlers do
      handle MyApp.Handler

      handle MyApp.FilteredHandler do
        filter interface: "org.interface.my"
      end
    end
    ```
    in this case we have two handlers. The first one is always called, the second one only if the trigger value `interface` is the corresponding value.

  - Event Type: this field can be customized to look for the specific event type on the astarte trigger.
  """

  @tag %Spark.Dsl.Entity{
    name: :tag,
    target: Ash.Astarte.Triggers.Resource.Tag,
    describe: "Configure the event type of the astarte trigger.",
    args: [:tag],
    schema: [
      tag: [
        type: :atom,
        required: true,
        doc: "The astarte interface type"
      ]
    ]
  }
  @handler %Spark.Dsl.Entity{
    name: :handler,
    args: [:module],
    target: Ash.Astarte.Triggers.Resource.HandlerTarget,
    describe: """
    A trigger handler. A module implementing `Ash.Astarte.Triggers.Handler`
    """,
    examples: [
      """
      handler MyApp.Triggers.IncomingData.InterfaceHandler do
         filter :interface, @my-interface-value
      end
      """
    ],
    schema: [
      module: [
        type: :atom,
        required: true,
        doc: "The handler module. It should implement the `Ash.Astarte.Triggers.Handler` behavior."
      ],
      filter: [
        type: :non_empty_keyword_list,
        doc:
          "An optional filter. It expects a keyword list of `attribute`: `value`. Matches the incoming trigger value for such attribute to send it to the corresponding handler."
      ]
    ]
  }
  @handlers %Spark.Dsl.Section{
    name: :handlers,
    entities: [@handler],
    describe: "Configure handler for incoming data on the astarte trigger."
  }
  @astarte_type %Spark.Dsl.Section{
    name: :astarte,
    entities: [@tag],
    describe: "Configure the corresponding event generated for an incoming trigger data."
  }
  use Spark.Dsl.Extension,
    sections: [@handlers, @astarte_type]

  @handler %Spark.Dsl.Entity{
    name: :handler,
    args: [:module],
    target: Ash.Astarte.Triggers.Resource.HandlerTarget,
    describe: """
    A trigger handler. A module implementing `Ash.Astarte.Triggers.Handler`
    """,
    examples: [
      """
      handler MyApp.Triggers.IncomingData.InterfaceHandler do
         filter :interface, @my-interface-value
      end
      """
    ],
    schema: [
      module: [
        type: :atom,
        required: true,
        doc: "The handler module. It should implement the `Ash.Astarte.Triggers.Handler` behavior."
      ],
      filter: [
        type: :non_empty_keyword_list,
        doc:
          "An optional filter. It expects a keyword list of `attribute`: `value`. Matches the incoming trigger value for such attribute to send it to the corresponding handler."
      ]
    ]
  }

  @handlers %Spark.Dsl.Section{
    name: :handlers,
    entities: [@handler],
    describe: "Configure handler for incoming data on the astarte trigger."
  }

  # credo:disable-for-next-line
end

defmodule Ash.Astarte.Triggers.Resource.Tag do
  @moduledoc """
  A module representing the resource tag in the trigger.
  """

  defstruct [:tag, :__spark_metadata__]

  @type t :: %__MODULE__{
          tag: atom(),
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }
end

defmodule Ash.Astarte.Triggers.Resource.HandlerTarget do
  @moduledoc """
  A module representing the handler.
  """

  defstruct [:module, :filter, :__spark_metadata__]

  @type t :: %__MODULE__{
          module: module(),
          filter: :non_empty_keyword_list,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }
end
