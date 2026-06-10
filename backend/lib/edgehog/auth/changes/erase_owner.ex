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

defmodule Edgehog.Auth.Changes.EraseOwner do
  @moduledoc """
  A change to remove the owner of a destroyed object in the FGA provider.

  Opts:
  - fga_type     :: atom. the type assigned to the resource in the FGA model

  Example tuple:
  ```fga
    {user:bob, owner, device:Simpl3D3vice1d}
  ```
  """
  use Ash.Resource.Change

  alias Edgehog.Auth.FGAService

  @needed_keys [:fga_type, :primary_key]

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
    Ash.Changeset.after_action(changeset, &erase_owner(&1, &2, opts))
  end

  defp erase_owner(_changeset, record, opts) do
    type = Keyword.get(opts, :fga_type)
    primary_key = Keyword.get(opts, :primary_key)

    id = Map.get(record, primary_key)
    fga_id = "#{type}:#{id}"

    with {:ok, user_list} <- FGAService.list_users(fga_id, "owner", "user") do
      # There should only be one owner for a resource, and it shouldn't be a userset nor a wildcard.
      # Handle None provider separately
      user =
        case user_list do
          :all -> "user:anon"
          [sub] -> "user:#{sub}"
        end

      with {:ok, _result} <- FGAService.delete(user, "owner", fga_id) do
        {:ok, record}
      end
    end
  end

  defp error_if_not_present(key, {opts, errors}) do
    error = "Missing key #{inspect(key)}."

    if Keyword.has_key?(opts, key),
      do: {opts, errors},
      else: {opts, [error | errors]}
  end
end
