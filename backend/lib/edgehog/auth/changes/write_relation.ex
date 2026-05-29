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

defmodule Edgehog.Auth.Changes.WriteRelation do
  @moduledoc """
  A change to write a relation in the FGA provider.

  This change expects some opts keys to build the tuple

  { destination_type:destination_id_field(value), relationship, source_type:source_id(value) }

  - `destination_type`  :: (optional) is the fga type in the model
  - `destination_id`    :: is the realtaionship's destination field to query to get the id of the tuple

  - `relationship`      :: is the ash relationship to query to get the destination fields
  - `relationship_type` :: (optional) is the actual fga type of the relationship (defaults to the name of the ash relationship)

  - `source_type`       :: is the fga type of the source resource
  - `source_id`         :: is the field to query to get the correct id to set in the FGA provider.


  A lot ! Let's see an example. Suppose we want to set the device <-> realm relationship:

  - relationship        : realm (it's called `realm` in the ash resource spec)
  - relationship_type   : realm. It's realm _also_ in the fga model! No need to set it twice

  - destination_type    : realm, which is the same as the relationship name, no need to set it twice
  - destination_id      : the name of the realm (our id is not astarte compatible)

  - source_type         : device
  - source_id           : device_id (the astarte device id, not our internal id)

  Hence:

  ```elixir
    change {Edgehog.Auth.Changes.WriteRelation destination_id: :name, relationship: :realm, source_type: :device, source_id: :device_id}
  ```

  With realm "test" and device_id "Simpl3D3vice1d" will write the tuple

  ```fga
    {realm:test, realm, device:Simpl3D3vice1d}
  ```
  """

  use Ash.Resource.Change

  alias Edgehog.Auth.FGAService

  require Logger

  # needed
  @rel :relationship
  @dest_id :destination_id
  @src_type :source_type
  @src_id :source_id

  # optional
  # Falls back to `:relationship` value
  @rel_type :relationship_type
  # Falls back to `:relationship` value
  @dest_type :destination_type

  @needed_keys [@rel, @dest_id, @src_type, @src_id]

  @impl Ash.Resource.Change
  def init(opts) do
    {_, errors} = Enum.reduce(@needed_keys, {opts, []}, &error_if_not_present/2)

    if Enum.empty?(errors),
      do: {:ok, opts},
      else: {:error, errors}
  end

  @impl Ash.Resource.Change
  def change(changeset, opts, _context) do
    Ash.Changeset.after_transaction(changeset, &write_rel_tuple(&1, &2, opts))
  end

  defp write_rel_tuple(_changeset, {:ok, result}, opts) do
    rel = Keyword.fetch!(opts, @rel)
    rel_type = Keyword.get(opts, @rel_type, rel)

    dest_type = Keyword.get(opts, @dest_type, rel)
    dest_id = Keyword.fetch!(opts, @dest_id)

    src_type = Keyword.fetch!(opts, @src_type)
    src_id = Keyword.fetch!(opts, @src_id)

    dest_id =
      result
      |> Ash.load!([{rel, dest_id}])
      |> Map.get(rel)
      |> Map.get(dest_id)
      |> to_string()

    src_id =
      result
      |> Ash.load!(src_id)
      |> Map.get(src_id)
      |> to_string()

    subj = "#{dest_type}:#{dest_id}"
    rel = to_string(rel_type)
    obj = "#{src_type}:#{src_id}"

    with {:ok, _} <- FGAService.write(subj, rel, obj) do
      {:ok, result}
    end
  end

  defp write_rel_tuple(_changeset, error, opts) do
    Logger.debug("Error while executing DB transaction. Skipping writing tuple on the provider.",
      error: error,
      opts: opts
    )

    error
  end

  defp error_if_not_present(key, {opts, errors}) do
    error = "Missing key #{inspect(key)}."

    if Keyword.has_key?(opts, key),
      do: {opts, errors},
      else: {opts, [error | errors]}
  end
end
