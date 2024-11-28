#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Changes.CheckImages do
  @moduledoc false
  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    deployment = changeset.data

    with :sent <- deployment.status,
         {:ok, deployment} <-
           Ash.load(deployment, device: :available_images, release: [containers: [:image]]) do
      available_images_ids =
        Enum.map(deployment.device.available_images, & &1.id)

      missing_images =
        deployment.release.containers
        |> Enum.map(& &1.image.id)
        |> Enum.reject(&(&1 in available_images_ids))

      if missing_images == [] do
        Ash.Changeset.change_attribute(changeset, :status, :created_images)
      else
        changeset
      end
    else
      _ ->
        changeset
    end
  end
end
