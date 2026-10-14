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

defmodule Edgehog.Containers.Deployment.Validations.Event do
  @moduledoc """
  Checks if the received event matches some fields.

  ## Keys
  - type :: required. Checks if the event value matches the type.
  """

  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidArgument
  alias Ash.Subject

  defmodule Opts do
    @moduledoc false
    use Spark.Options.Validator,
      schema: [
        type: [
          type: :atom,
          required: true,
          doc: "The target value of the event type."
        ]
      ]
  end

  @impl Ash.Resource.Validation
  def init(opts) do
    case Opts.validate(opts) do
      {:ok, opts} ->
        {:ok, Opts.to_options(opts)}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  @impl Ash.Resource.Validation
  def validate(subject, opts, _context) do
    event = Subject.get_argument(subject, :event)
    target_value = opts[:type]

    %{type: type} = event

    if type != target_value do
      error =
        InvalidArgument.exception(field: [event: :type], value: event.type)

      {:error, error}
    else
      :ok
    end
  end
end
