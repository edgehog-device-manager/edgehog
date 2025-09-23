#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Container.Changes.Relate do
  @moduledoc false

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    with {:ok, container} <- Ash.Changeset.fetch_argument(changeset, :container),
         {:ok, device} <- Ash.Changeset.fetch_argument(changeset, :device),
         {:ok, deployment} <- Ash.Changeset.fetch_argument(changeset, :deployment),
         {:ok, container} <-
           Ash.load(container, [:image, :volumes, :networks, :device_mappings], tenant: tenant) do
      image = container.image
      networks = container.networks
      volumes = container.volumes
      device_mappings = container.device_mappings

      image_input = %{
        image: image,
        device: device,
        deployment: deployment,
        image_id: image.id,
        device_id: device.id
      }

      networks_input =
        Enum.map(networks, fn network ->
          %{
            network: network,
            device: device,
            deployment: deployment,
            network_id: network.id,
            device_id: device.id
          }
        end)

      volumes_input =
        Enum.map(volumes, fn volume ->
          %{
            volume: volume,
            device: device,
            deployment: deployment,
            volume_id: volume.id,
            device_id: device.id
          }
        end)

      device_mappings_input =
        Enum.map(device_mappings, fn device_mapping ->
          %{
            device_mapping: device_mapping,
            device: device,
            deployment: deployment,
            device_mapping_id: device_mapping.id,
            device_id: device.id
          }
        end)

      changeset
      |> Ash.Changeset.manage_relationship(:image_deployment, image_input,
        on_no_match: {:create, :deploy},
        on_lookup: :relate,
        use_identities: [:image_instance]
      )
      |> Ash.Changeset.manage_relationship(:network_deployments, networks_input,
        on_no_match: {:create, :deploy},
        on_lookup: :relate,
        use_identities: [:network_instance]
      )
      |> Ash.Changeset.manage_relationship(:volume_deployments, volumes_input,
        on_no_match: {:create, :deploy},
        on_lookup: :relate,
        use_identities: [:volume_instance]
      )
      |> Ash.Changeset.manage_relationship(:device_mapping_deployments, device_mappings_input,
        on_no_match: {:create, :deploy},
        on_lookup: :relate,
        use_identities: [:device_mapping_instance]
      )
    end
  end
end
