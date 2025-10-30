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

defmodule Edgehog.Containers.Container.Deployment.Changes.MaybeDeleteChildren do
  @moduledoc """
  Trigger Image, Volume, Network and DeviceMappings deletion if dangling
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    with {:ok, container_deployment} <-
           Ash.load(changeset.data, [
             :image_deployment,
             :volume_deployments,
             :network_deployments,
             :device_mapping_deployments
           ]) do
      resources =
        [container_deployment.image_deployment] ++
          container_deployment.volume_deployments ++
          container_deployment.network_deployments ++
          container_deployment.device_mapping_deployments

      Ash.Changeset.after_action(changeset, fn _changeset, container_deployment ->
        Enum.each(resources, fn resource ->
          resource
          |> Ash.Changeset.for_destroy(:destroy_if_dangling, %{})
          |> Ash.destroy!(tenant: tenant)
        end)

        {:ok, container_deployment}
      end)
    end
  end
end
