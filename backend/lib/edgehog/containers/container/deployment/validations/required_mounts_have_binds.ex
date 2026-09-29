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

defmodule Edgehog.Containers.Container.Deployment.Validations.RequiredMountsHaveBinds do
  @moduledoc """
  When creating a container deployment, ensures that required file mounts have a referencing file bind.
  """

  use Ash.Resource.Validation

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    # NOTE: `container` is required: `allow_nil: false`
    {:ok, container} = Ash.Changeset.fetch_argument(changeset, :container)

    loaded_container = Ash.load!(container, :file_mounts)

    required_file_mounts =
      loaded_container
      |> Map.fetch!(:file_mounts)
      |> Enum.filter(&required_and_not_bound/1)

    file_binds = get_file_binds(changeset)

    with :ok <- validate_unique_mounts(file_binds),
         :ok <- validate_mounts_belong_to_container(file_binds, loaded_container) do
      validate_required_mounts(required_file_mounts, file_binds)
    end
  end

  defp get_file_binds(changeset) do
    Ash.Changeset.get_argument(changeset, :file_binds) || []
  end

  defp validate_unique_mounts(file_binds) do
    mount_ids =
      file_binds
      |> Enum.map(& &1.file_mount_id)
      |> Enum.reject(&(&1 == nil))

    if mount_ids != Enum.uniq(mount_ids),
      do: {:error, field: :file_binds, message: "Duplicate file mounts are not allowed."},
      else: :ok
  end

  defp validate_mounts_belong_to_container(file_binds, container) do
    allowed_ids =
      container
      |> Map.fetch!(:file_mounts)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    invalid =
      file_binds
      |> Enum.map(& &1.file_mount_id)
      |> Enum.reject(&(&1 == nil || MapSet.member?(allowed_ids, &1)))

    case invalid do
      [] ->
        :ok

      _ ->
        {:error, field: :file_binds, message: "Some file mounts do not belong to the container."}
    end
  end

  defp validate_required_mounts(required_file_mounts, file_binds) do
    assoc_ids = Enum.map(file_binds, & &1.file_mount_id)
    required_ok? = Enum.all?(required_file_mounts, &(&1.id in assoc_ids))

    if required_ok?,
      do: :ok,
      else: {:error, field: :file_binds, message: "Some required mountpoints are not being set."}
  end

  # If they are not required -> skip
  defp required_and_not_bound(%{required: false}), do: false
  # If they are required and there is no default file -> keep
  defp required_and_not_bound(%{default_file_id: nil}), do: true
  # If they are required but there is a default file -> skip
  defp required_and_not_bound(%{default_file_id: _}), do: false
end
