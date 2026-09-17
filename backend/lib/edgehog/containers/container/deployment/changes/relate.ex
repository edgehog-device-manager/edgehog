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

defmodule Edgehog.Containers.Container.Deployment.Changes.Relate do
  @moduledoc false

  use Ash.Resource.Change

  alias Edgehog.Containers.Container.Env

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    with {:ok, container} <- Ash.Changeset.fetch_argument(changeset, :container),
         {:ok, device} <- Ash.Changeset.fetch_argument(changeset, :device),
         {:ok, deployment} <- Ash.Changeset.fetch_argument(changeset, :deployment),
         {:ok, container} <-
           Ash.load(
             container,
             [
               :image,
               :volumes,
               :networks,
               :device_mappings,
               :device_requests,
               file_mounts: [:default_file]
             ],
             tenant: tenant
           ) do
      image = container.image
      networks = container.networks
      volumes = container.volumes
      device_mappings = container.device_mappings
      device_requests = container.device_requests

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

      device_requests_input =
        Enum.map(device_requests, fn device_request ->
          %{
            device_request: device_request,
            device: device,
            deployment: deployment,
            device_request_id: device_request.id,
            device_id: device.id
          }
        end)

      {env, env_strategy} = resolve_env(changeset, container)

      file_binds_input =
        changeset
        |> Ash.Changeset.get_argument(:file_binds)
        |> relate_file_binds(device, container, tenant)

      changeset
      |> Ash.Changeset.change_attribute(:env, env)
      |> Ash.Changeset.change_attribute(:env_strategy, env_strategy)
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
      |> Ash.Changeset.manage_relationship(
        :device_mapping_deployments,
        device_mappings_input,
        on_no_match: {:create, :deploy},
        on_lookup: :relate,
        use_identities: [:device_mapping_instance]
      )
      |> Ash.Changeset.manage_relationship(
        :device_request_deployments,
        device_requests_input,
        on_no_match: {:create, :deploy},
        on_lookup: :relate,
        use_identities: [:device_request_instance]
      )
      |> Ash.Changeset.manage_relationship(:file_binds, file_binds_input,
        on_no_match: :create,
        on_match: :ignore,
        on_lookup: :ignore
      )
    end
  end

  defp relate_file_binds(nil, device, container, tenant),
    do: relate_file_binds([], device, container, tenant)

  defp relate_file_binds(file_binds, device, container, tenant) do
    explicit =
      (file_binds || [])
      |> Enum.map(&Map.put(&1, :device_id, device.id))

    explicit_ids =
      explicit
      |> Enum.map(& &1.file_mount_id)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    default_binds =
      container.file_mounts
      |> Enum.reject(&MapSet.member?(explicit_ids, &1.id))
      |> Enum.filter(& &1.default_file_id)
      |> Enum.map(&default_file_bind(&1, device, tenant))
      |> Enum.reject(&is_nil/1)

    explicit ++ default_binds
  end

  defp default_file_bind(%{default_file: nil} = file_mount, _device, _tenant) do
    Logger.error("File mount #{file_mount.id} has default_file_id but default_file not loaded")
    nil
  end

  defp default_file_bind(file_mount, device, tenant) do
    file = file_mount.default_file

    case create_managed_download_request(file, device, tenant) do
      {:ok, request} ->
        %{
          file_mount_id: file_mount.id,
          file_download_request_id: request.id,
          device_id: device.id
        }

      {:error, reason} ->
        raise "Failed to create download request for default file #{file_mount.id}: #{inspect(reason)}"
    end
  end

  defp create_managed_download_request(file, device, tenant) do
    Edgehog.Files.FileDownloadRequest
    |> Ash.Changeset.for_create(
      :managed,
      %{destination_type: :storage, file_id: file.id, device_id: device.id},
      tenant: tenant
    )
    |> Ash.create(tenant: tenant)
  end

  defp resolve_env(changeset, container) do
    deploy_env = Ash.Changeset.get_argument(changeset, :env) || []
    env_strategy = Ash.Changeset.get_argument(changeset, :env_strategy) || :merge
    resolved = Env.resolve(container.env || [], deploy_env, env_strategy)
    {resolved, env_strategy}
  end
end
