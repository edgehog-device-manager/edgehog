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

defmodule Edgehog.Auth.Policies.Check do
  @moduledoc """
  An `Ash.Policy.SimpleCheck` check to query the provider for a specific `relation` with `object`

  To use it, call it this way in a policy
  ```elixir
  {Edgehog.Auth.Policies.Check, id: :id_attribute, rel: :can_view, obj: "deployment"}
  ```

  The following opts are available:
  - `rel` (required) :: the relationship you want to check for.
  - `obj` (required) :: type object you want to check for.
  - `obj_id`         :: the id of the resource. This is used to build the value `type:id` for the object in the tuple.

  Example: for devices

  ```elixir
  alias Edgehog.Auth.Policies.Check

  # This can be used to authorize reads on single devices
  authorize_if {Check, rel: :can_view, obj: :device, obj_id: :device_id}
  ```
  """
  use Ash.Policy.SimpleCheck

  alias Edgehog.Auth.FGAService

  require Logger

  @subject_type "user"

  @impl Ash.Policy.SimpleCheck
  def match?(actor, %{data: data}, opts) do
    obj_id = Keyword.get(opts, :obj_id, :id)

    subj = actor.sub
    rel = opts |> Keyword.fetch!(:rel) |> to_string()
    obj = opts |> Keyword.fetch!(:obj) |> to_string()

    obj_id =
      data
      |> Ash.load!(obj_id)
      |> Map.get(obj_id, "*")
      |> to_string()

    Logger.debug("Authorizing a tuple",
      subject: @subject_type,
      subject_id: subj,
      relationship: rel,
      object: obj,
      object_id: obj
    )

    FGAService.check("#{@subject_type}:#{subj}", rel, "#{obj}:#{obj_id}")
  end

  @impl Ash.Policy.Check
  def describe(opts) do
    rel = Keyword.fetch!(opts, :rel)
    obj = Keyword.fetch!(opts, :obj)
    obj_id = Keyword.get(opts, :obj_id, :id)

    "Checking if the actor has relation #{inspect(rel)} on #{inspect(obj)} (using field #{inspect(obj_id)} for ID)"
  end
end
