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

defmodule Edgehog.Containers.Release.Changes.HandleRelatedResourcesDeletion do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Error.Changes.InvalidArgument
  alias Edgehog.Containers.ReleaseContainers

  require Logger

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      release = changeset.data

      # Load the release with its containers, and the containers with their images
      release =
        Ash.load!(
          release,
          [
            :deployments,
            containers: [:image]
          ],
          reuse_values?: true
        )

      handle_release_deletion(changeset, release)
    end)
  end

  defp handle_release_deletion(changeset, release) do
    # Check if the release has any active deployments
    case release.deployments do
      [] ->
        # No deployments, safe to proceed with deletion
        # Clean up related resources before deleting the release
        cleanup_related_resources(release)
        changeset

      deployments ->
        # There are deployments, check if any are in a state that prevents deletion
        active_deployments =
          Enum.filter(deployments, fn deployment ->
            deployment.state not in [nil, :stopped, :deleting, :error]
          end)

        case active_deployments do
          [] ->
            # All deployments are in a terminal state, safe to delete them first
            # then proceed with release and container cleanup
            delete_deployments(release.deployments, release.__metadata__.tenant)
            cleanup_related_resources(release)
            changeset

          _ ->
            # There are active deployments, prevent deletion
            Ash.Changeset.add_error(
              changeset,
              InvalidArgument.exception(
                field: :id,
                message: "Cannot delete release with active deployments. Please stop or delete all deployments first."
              )
            )
        end
    end
  end

  defp cleanup_related_resources(release) do
    Logger.info("Starting cleanup for release #{release.id} with #{length(release.containers)} containers")

    # For each container in the release
    for container <- release.containers do
      # First, find all releases that use this container (through the join table)
      releases_using_container =
        ReleaseContainers
        |> Ash.Query.filter(container_id == ^container.id)
        |> Ash.read!(tenant: release.__metadata__.tenant)

      # Remove the current release from the list to see if others are using this container
      other_releases_using_container =
        Enum.reject(releases_using_container, &(&1.release_id == release.id))

      if Enum.empty?(other_releases_using_container) do
        # Container is only used by this release, safe to delete
        Logger.info("Container #{container.id} is only used by release #{release.id}, will delete")

        # Check if the image is used by other containers
        image = container.image

        containers_using_image =
          Edgehog.Containers.Container
          |> Ash.Query.filter(image_id == ^image.id)
          |> Ash.read!(tenant: release.__metadata__.tenant)

        # First, manually delete all join table records for this container

        # Delete release-container relationship
        release_container_record =
          ReleaseContainers
          |> Ash.Query.filter(release_id == ^release.id and container_id == ^container.id)
          |> Ash.read!(tenant: release.__metadata__.tenant)
          |> List.first()

        if release_container_record do
          Logger.info("Deleting release-container join record for release #{release.id} and container #{container.id}")

          _ = Ash.destroy!(release_container_record, tenant: release.__metadata__.tenant)
        end

        # Delete container-network relationships
        container_network_records =
          Edgehog.Containers.ContainerNetwork
          |> Ash.Query.filter(container_id == ^container.id)
          |> Ash.read!(tenant: release.__metadata__.tenant)

        for container_network_record <- container_network_records do
          Logger.info(
            "Deleting container-network join record for container #{container.id} and network #{container_network_record.network_id}"
          )

          _ = Ash.destroy!(container_network_record, tenant: release.__metadata__.tenant)
        end

        # Now delete the container
        _ = Ash.destroy!(container, tenant: release.__metadata__.tenant)

        # If this was the only container using the image, delete the image too
        if length(containers_using_image) == 1 do
          Logger.info("Image #{image.id} was only used by container #{container.id}, will delete")

          _ = Ash.destroy!(image, tenant: release.__metadata__.tenant)
        else
          Logger.info("Image #{image.id} is used by #{length(containers_using_image)} containers, keeping")
        end
      else
        Logger.info(
          "Container #{container.id} is used by #{length(other_releases_using_container)} other releases, keeping"
        )
      end
    end

    :ok
  rescue
    error ->
      # Log the error but don't fail the release deletion
      Logger.warning("Failed to cleanup related resources for release #{release.id}: #{inspect(error)}")

      :ok
  end

  defp delete_deployments(deployments, tenant) do
    Logger.info("Deleting #{length(deployments)} deployments before release deletion")

    for deployment <- deployments do
      Logger.info("Deleting deployment #{deployment.id} (state: #{deployment.state})")

      case Ash.destroy(deployment, tenant: tenant) do
        {:ok, _} ->
          Logger.info("Successfully deleted deployment #{deployment.id}")

        :ok ->
          Logger.info("Successfully deleted deployment #{deployment.id}")

        {:error, error} ->
          Logger.warning("Failed to delete deployment #{deployment.id}: #{inspect(error)}")
          # Continue with other deployments even if one fails
      end
    end

    :ok
  rescue
    error ->
      Logger.warning("Failed to delete deployments: #{inspect(error)}")
      :ok
  end
end
