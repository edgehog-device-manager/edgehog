#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

  alias Edgehog.Containers

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    deployment = changeset.data
    %{tenant: tenant} = context

    with :initial <- deployment.resources_state,
         {:ok, deployment} <-
           Ash.load(deployment, device: [], release: [containers: [:image]]) do
      device = deployment.device

      images_ready? =
        deployment.release.containers
        |> Enum.map(& &1.image)
        |> Enum.uniq_by(& &1.id)
        |> Enum.map(&Containers.fetch_image_deployment!(&1.id, device.id, tenant: tenant, load: [:ready?]))
        |> Enum.all?(& &1.ready?)

      if images_ready?,
        do: Ash.Changeset.change_attribute(changeset, :resources_state, :created_images),
        else: changeset
    else
      _ ->
        changeset
    end
  end
end
