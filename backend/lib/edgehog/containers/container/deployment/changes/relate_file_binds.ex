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

defmodule Edgehog.Containers.Container.Deployment.Changes.RelateFileBinds do
  @moduledoc """
  Resolves explicit and default `:file_binds` for a container deployment,
  inheriting default file ownership and mode attributes from each mount.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    with true <- changeset.valid?,
         {:ok, container} <- Ash.Changeset.fetch_argument(changeset, :container),
         {:ok, device} <- Ash.Changeset.fetch_argument(changeset, :device),
         {:ok, container} <- Ash.load(container, [:file_mounts], tenant: tenant) do
      file_binds_input =
        changeset
        |> Ash.Changeset.get_argument(:file_binds)
        |> resolve_file_binds(device, container.file_mounts)

      Ash.Changeset.manage_relationship(changeset, :file_binds, file_binds_input,
        on_no_match: :create,
        on_match: :ignore,
        on_lookup: :ignore
      )
    else
      {:error, error} -> Ash.Changeset.add_error(changeset, error)
      _ -> changeset
    end
  end

  defp resolve_file_binds(file_binds, device, file_mounts) do
    file_binds = file_binds || []
    file_mounts = List.wrap(file_mounts)
    mounts_by_id = Map.new(file_mounts, &{&1.id, &1})

    explicit_ids =
      file_binds
      |> Enum.map(&get_value(&1, :file_mount_id))
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    explicit =
      Enum.map(file_binds, fn bind ->
        mount_id = get_value(bind, :file_mount_id)
        mount = Map.get(mounts_by_id, mount_id)

        bind
        |> Map.put(:device_id, device.id)
        |> resolve_bind_permissions(mount)
      end)

    default_binds =
      file_mounts
      |> Enum.filter(&(not MapSet.member?(explicit_ids, &1.id) and &1.default_file_id))
      |> Enum.map(&default_file_bind(&1, device))

    explicit ++ default_binds
  end

  defp resolve_bind_permissions(bind, nil), do: bind

  defp resolve_bind_permissions(bind, mount) do
    file_mode = get_value(bind, :file_mode) || mount.file_mode
    user_id = get_value(bind, :user_id) || mount.user_id
    group_id = get_value(bind, :group_id) || mount.group_id

    bind
    |> maybe_put(:file_mode, file_mode)
    |> maybe_put(:user_id, user_id)
    |> maybe_put(:group_id, group_id)
  end

  defp default_file_bind(file_mount, device) do
    %{
      file_mount_id: file_mount.id,
      device_id: device.id
    }
    |> maybe_put(:file_mode, file_mount.file_mode)
    |> maybe_put(:user_id, file_mount.user_id)
    |> maybe_put(:group_id, file_mount.group_id)
  end

  defp get_value(map, key) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key)))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
