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

defmodule Edgehog.Auth.Changes.EraseAlias do
  @moduledoc """
  A change to erase the alias for an object in the FGA provider.

  Opts:
  - alias_attr   :: atom. the attribute to be used as an alias for the resource
  - fga_type     :: atom. the type assigned to the resource in the FGA model

  An alias is useful, for example, for resources defining an attribute to use for their FGA id that is different than the
  their actual id: this way the FGA service can still check programmatically by using the id provided by Ash, but it is
  also possible for a human to inspect the status manually.

  For example, devices use `device_id` instead of `id`. With this change, the tuples
  ```fga
    {device:Simpl3D3vice1d, alias, device:<uuid>}
  ```
  and
  ```fga
    {device:<uuid>, alias, device:Simpl3D3vice1d}
  ```
  will be deleted by the FGA service.
  """
  use Ash.Resource.Change

  alias Edgehog.Auth.FGAService

  @needed_keys [:alias_attr, :fga_type, :primary_key]

  @impl Ash.Resource.Change
  def init(opts) do
    {_, errors} = Enum.reduce(@needed_keys, {opts, []}, &error_if_not_present/2)

    if Enum.empty?(errors),
      do: {:ok, opts},
      else: {:error, errors}
  end

  @impl Ash.Resource.Change
  def change(%{valid: false} = changeset, _opts, _context), do: changeset

  @impl Ash.Resource.Change
  def change(%{action_type: :destroy} = changeset, opts, _context) do
    Ash.Changeset.after_action(changeset, &erase_alias(&1, &2, opts))
  end

  defp erase_alias(_changeset, record, opts) do
    alias_attr = Keyword.get(opts, :alias_attr)
    type = Keyword.get(opts, :fga_type)
    primary_key = Keyword.get(opts, :primary_key)

    id = Map.get(record, primary_key)
    fga_id = "#{type}:#{id}"
    alias = Map.get(record, alias_attr)
    fga_alias = "#{type}:#{alias}"

    with {:ok, _result} <- FGAService.delete(fga_alias, "alias", fga_id),
         {:ok, _result} <- FGAService.delete(fga_id, "alias", fga_alias) do
      {:ok, record}
    end
  end

  defp error_if_not_present(key, {opts, errors}) do
    error = "Missing key #{inspect(key)}."

    if Keyword.has_key?(opts, key),
      do: {opts, errors},
      else: {opts, [error | errors]}
  end
end
