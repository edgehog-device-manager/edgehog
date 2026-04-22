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

defmodule Ash.Astarte.Triggers.Domain do
  @moduledoc """
  The edgheog domain extension for astarte triggers.

  With this extension a domain registers resource that handle triggers.
  """

  @fallback_handler %Spark.Dsl.Entity{
    name: :handler,
    target: Ash.Astarte.Triggers.Resource.HandlerTarget,
    describe: """
    A fallback handler. This handler will handle raw data when it is not possible to cast
    the received trigger to any of the available trigger target.
    """,
    examples: [
      """
      triggers do
          trigger Edgehog.Triggers.IncomingData
          trigger Edgehog.Triggers.DeviceConnected
          trigger Edgehog.Triggers.DeviceDisconnected
          # ...

          fallback_handler Edgehog.Triggers.Handlers.Fallback
      end
      """
    ],
    schema: [
      module: [
        type: :module,
        required: true,
        doc: "The trigger module."
      ]
    ],
    args: [:module]
  }
  @trigger %Spark.Dsl.Entity{
    name: :trigger,
    target: Ash.Astarte.Triggers.Domain.TriggerTarget,
    describe: """
    A trigger module. Ideally an ash resource with `Edgehog.Triggers.Resource.Extension` extension.
    """,
    examples: [
      """
      triggers do
          trigger Edgehog.Triggers.IncomingData
          trigger Edgehog.Triggers.DeviceConnected
          trigger Edgehog.Triggers.DeviceDisconnected
          # ...
      end
      """
    ],
    schema: [
      module: [
        type: :module,
        required: true,
        doc: "The trigger module."
      ]
    ],
    args: [:module]
  }
  @triggers %Spark.Dsl.Section{
    name: :triggers,
    entities: [@trigger],
    describe: "Configure the triggers of the application."
  }
  @handlers %Spark.Dsl.Section{
    name: :fallback_handlers,
    entities: [@fallback_handler],
    describe: "Configure the triggers of the application."
  }
  use Spark.Dsl.Extension,
    sections: [@triggers, @handlers]

  @trigger %Spark.Dsl.Entity{
    name: :trigger,
    target: Ash.Astarte.Triggers.Domain.TriggerTarget,
    describe: """
    A trigger module. Ideally an ash resource with `Edgehog.Triggers.Resource.Extension` extension.
    """,
    examples: [
      """
      triggers do
          trigger Edgehog.Triggers.IncomingData
          trigger Edgehog.Triggers.DeviceConnected
          trigger Edgehog.Triggers.DeviceDisconnected
          # ...
      end
      """
    ],
    schema: [
      module: [
        type: :module,
        required: true,
        doc: "The trigger module."
      ]
    ],
    args: [:module]
  }

  @triggers %Spark.Dsl.Section{
    name: :triggers,
    entities: [@trigger],
    describe: "Configure the triggers of the application."
  }

  # credo:disable-for-next-line
end

defmodule Ash.Astarte.Triggers.Domain.TriggerTarget do
  @moduledoc """
  A module representing the trigger target.
  """

  defstruct [:module, :__spark_metadata__]

  @type t :: %__MODULE__{
          module: module(),
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }
end
