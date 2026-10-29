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

defmodule Edgehog.Containers.Release.Changes.Copy do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers.Container

  @release_loads [
    :system_models,
    :container_dependencies,
    containers: [
      :image,
      :networks,
      :file_mounts,
      :device_mappings,
      :device_requests,
      container_volumes: [:volume]
    ]
  ]

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    with {:ok, release} <- Ash.Changeset.fetch_argument(changeset, :release),
         {:ok, release} <- Ash.load(release, @release_loads, tenant: tenant) do
      container_id_map = build_id_map(release.containers)
      image_id_map = release.containers |> Enum.map(& &1.image) |> build_id_map()

      volume_id_map =
        release.containers
        |> Enum.flat_map(& &1.container_volumes)
        |> Enum.map(& &1.volume)
        |> build_id_map()

      network_id_map =
        release.containers
        |> Enum.flat_map(& &1.networks)
        |> build_id_map()

      containers_inputs =
        Enum.map(release.containers, fn container ->
          build_container_input(
            container,
            container_id_map,
            image_id_map,
            volume_id_map,
            network_id_map
          )
        end)

      dependencies_inputs =
        Enum.map(release.container_dependencies, fn dep ->
          %{
            container_id: Map.fetch!(container_id_map, dep.container_id),
            dependency_id: Map.fetch!(container_id_map, dep.dependency_id)
          }
        end)

      changeset
      |> Ash.Changeset.force_change_attribute(:application_id, release.application_id)
      |> Ash.Changeset.force_change_attribute(:version, release.version)
      |> Ash.Changeset.manage_relationship(:containers, containers_inputs,
        on_no_match: {:create, :copy},
        on_lookup: :relate
      )
      |> Ash.Changeset.manage_relationship(:system_models, release.system_models, type: :append)
      |> Ash.Changeset.manage_relationship(:container_dependencies, dependencies_inputs,
        type: :create
      )
    else
      :error ->
        Ash.Changeset.add_error(changeset, field: :release, message: "is required")

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  defp build_id_map(resources) do
    resources
    |> Enum.uniq_by(& &1.id)
    |> Map.new(&{&1.id, Ash.UUID.generate()})
  end

  defp build_container_input(
         container,
         container_id_map,
         image_id_map,
         volume_id_map,
         network_id_map
       ) do
    image_input =
      container.image
      |> Map.from_struct()
      |> Map.put(:id, Map.fetch!(image_id_map, container.image.id))

    volumes_inputs =
      Enum.map(container.container_volumes, fn cv ->
        cv.volume
        |> Map.from_struct()
        |> Map.put(:id, Map.fetch!(volume_id_map, cv.volume.id))
        |> Map.put(:target, cv.target)
      end)

    networks_inputs =
      Enum.map(container.networks, fn network ->
        network
        |> Map.from_struct()
        |> Map.put(:id, Map.fetch!(network_id_map, network.id))
      end)

    file_mounts_inputs =
      Enum.map(container.file_mounts, fn fm ->
        fm
        |> Map.from_struct()
        |> Map.drop([:id, :container_id])
      end)

    device_mappings_inputs =
      Enum.map(container.device_mappings, fn dm ->
        dm
        |> Map.from_struct()
        |> Map.drop([:id, :container_id])
      end)

    device_requests_inputs =
      Enum.map(container.device_requests, fn dr ->
        dr
        |> Map.from_struct()
        |> Map.drop([:id, :container_id])
      end)

    container
    |> Map.take(Container.container_attributes())
    |> Map.merge(%{
      id: Map.fetch!(container_id_map, container.id),
      image: image_input,
      volumes: volumes_inputs,
      networks: networks_inputs,
      file_mounts: file_mounts_inputs,
      device_mappings: device_mappings_inputs,
      device_requests: device_requests_inputs
    })
  end
end
