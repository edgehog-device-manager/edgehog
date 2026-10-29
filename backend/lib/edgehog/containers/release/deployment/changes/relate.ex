#
# This file is part of Edgehog.
#
# Copyright 2025-2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Release.Deployment.Changes.Relate do
  @moduledoc """
  Relates a deployment to underlying container deployments, by creating a deep
  copy of the release and its underlying container resources when deployed.
  """
  use Ash.Resource.Change

  alias Edgehog.Containers.Release
  alias Edgehog.Devices.Device

  @impl Ash.Resource.Change
  def change(%{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, %{tenant: tenant}) do
    deployment = changeset.data

    device_id = Ash.Changeset.get_argument(changeset, :device_id)
    release_id = Ash.Changeset.get_attribute(changeset, :release_id)
    configs = Ash.Changeset.get_argument(changeset, :configs)

    release = Ash.get!(Release, release_id, load: [containers: [:file_mounts]], tenant: tenant)
    device = Ash.get!(Device, device_id, tenant: tenant)

    case copy_release(release, tenant) do
      {:ok, copied_release} ->
        remapped_configs = remap_configs(configs, release.containers, copied_release.containers)

        inputs =
          Enum.map(copied_release.containers, fn container ->
            container_deployment_input(container, device, deployment, remapped_configs)
          end)

        changeset
        |> Ash.Changeset.force_change_attribute(:release_id, copied_release.id)
        |> Ash.Changeset.manage_relationship(:container_deployments, inputs,
          on_no_match: {:create, :deploy},
          on_match: :ignore,
          on_lookup: {:relate, :create},
          use_identities: [:container_instance]
        )

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  defp copy_release(release, tenant) do
    Release
    |> Ash.Changeset.for_create(:copy, %{release: release}, tenant: tenant)
    |> Ash.create(load: [containers: [:file_mounts]], tenant: tenant)
  end

  defp remap_configs(configs, orig_containers, copied_containers) do
    copied_by_name = Map.new(copied_containers, &{&1.name, &1})

    container_map =
      Map.new(orig_containers, fn orig ->
        {to_string(orig.id), Map.fetch!(copied_by_name, orig.name)}
      end)

    file_mount_map =
      Enum.reduce(orig_containers, %{}, fn orig, acc ->
        copied = Map.fetch!(copied_by_name, orig.name)
        copied_mounts_by_mp = Map.new(copied.file_mounts || [], &{&1.mountpoint, &1.id})

        Enum.reduce(orig.file_mounts || [], acc, fn fm, inner_acc ->
          Map.put(inner_acc, to_string(fm.id), Map.fetch!(copied_mounts_by_mp, fm.mountpoint))
        end)
      end)

    Enum.map(configs || [], fn entry ->
      orig_cid = to_string(config_value(entry, :container_id))

      case Map.fetch(container_map, orig_cid) do
        {:ok, copied_container} ->
          file_binds =
            entry
            |> config_value(:file_binds)
            |> List.wrap()
            |> Enum.map(&remap_file_bind(&1, file_mount_map))

          entry
          |> Map.put(:container_id, copied_container.id)
          |> Map.put(:file_binds, file_binds)

        :error ->
          entry
      end
    end)
  end

  defp remap_file_bind(bind, file_mount_map) do
    orig_fm_id = to_string(config_value(bind, :file_mount_id))

    case Map.fetch(file_mount_map, orig_fm_id) do
      {:ok, copied_fm_id} -> Map.put(bind, :file_mount_id, copied_fm_id)
      :error -> bind
    end
  end

  defp container_deployment_input(container, device, deployment, configs) do
    container_id = to_string(container.id)

    config =
      Enum.find(configs, %{}, fn entry ->
        to_string(config_value(entry, :container_id)) == container_id
      end)

    %{
      container: container,
      container_id: container.id,
      device: device,
      device_id: device.id,
      deployment: deployment,
      env: config_value(config, :env),
      env_strategy: config_value(config, :env_strategy),
      file_binds: config_value(config, :file_binds) || [],
      env_files: config_value(config, :env_files) || []
    }
  end

  defp config_value(config, key) when is_map(config) and is_atom(key) do
    Map.get(config, key, Map.get(config, Atom.to_string(key)))
  end

  defp config_value(_config, _key), do: nil
end
