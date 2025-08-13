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

defmodule Edgehog.Containers.Release.Changes.CleanupContainers do
  @moduledoc false

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    release = changeset.data
    %{tenant: tenant} = context

    # Preload containers on the release
    {:ok, release_with_containers} = Ash.load(release, :containers, tenant: tenant)
    containers = release_with_containers.containers

    # Use after_action to perform cleanup - this will revert the transaction if cleanup fails
    Ash.Changeset.after_action(changeset, fn _changeset, release ->
      cleanup_dangling_containers(containers, tenant)
      {:ok, release}
    end)
  end

  defp cleanup_dangling_containers(containers, tenant) do
    # Load both dangling? and image for each container
    {:ok, containers_with_data} = Ash.load(containers, [:dangling?, :image], tenant: tenant)

    for container <- containers_with_data do
      if container.dangling? do
        cleanup_dangling_container(container, tenant)
      end
    end
  end

  defp cleanup_dangling_container(container, tenant) do
    image = container.image

    # Container is dangling, destroy it
    Ash.destroy!(container, tenant: tenant)

    # Check if image is now dangling and destroy it too
    if image do
      {:ok, image_with_dangling} = Ash.load(image, :dangling?, tenant: tenant)

      if image_with_dangling.dangling? do
        Ash.destroy!(image, tenant: tenant)
      end
    end
  end
end
