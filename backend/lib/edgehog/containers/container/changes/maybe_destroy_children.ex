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

defmodule Edgehog.Containers.Container.Changes.MaybeDestroyChildren do
  @moduledoc """
  Change to run `destroy_if_dangling` on container child resources (images, volumes, networks, device_mappings).
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    container = changeset.data

    with {:ok, container} <- Ash.load(container, [:image, :volumes, :networks, :device_mappings]) do
      Ash.Changeset.after_action(changeset, fn _changeset, after_container ->
        # Only destroying image and device mapping in this case. Volumes and
        # networks are user-definied and managed resources, let's leave them
        # alone.
        resources =
          [container.image] ++ container.device_mappings

        Enum.each(resources, fn resource ->
          resource
          |> Ash.Changeset.for_destroy(:destroy_if_dangling, %{})
          |> Ash.destroy(tenant: tenant)
        end)

        {:ok, after_container}
      end)
    end
  end
end
