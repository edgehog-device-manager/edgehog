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

defmodule Edgehog.Containers.Deployment.Changes.Relate do
  @moduledoc """
  Relates a deployment to underlying container deployments, by creating them when
  needed.
  """
  use Ash.Resource.Change

  alias Edgehog.Containers.Release
  alias Edgehog.Devices.Device

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    deployment = changeset.data

    device_id = Ash.Changeset.get_argument(changeset, :device_id)
    release_id = Ash.Changeset.get_attribute(changeset, :release_id)

    release = Ash.get!(Release, release_id, load: :containers, tenant: tenant)
    device = Ash.get!(Device, device_id, tenant: tenant)

    containers = release.containers
    configs = Ash.Changeset.get_argument(changeset, :configs) || []

    inputs = Enum.map(containers, &container_deployment_input(&1, device, deployment, configs))

    Ash.Changeset.manage_relationship(
      changeset,
      :container_deployments,
      inputs,
      on_no_match: {:create, :deploy},
      on_match: :ignore,
      on_lookup: {:relate, :create},
      use_identities: [:container_instance]
    )
  end

  defp container_deployment_input(container, device, deployment, configs) do
    container_id = container.id

    config = Enum.find(configs, %{}, &match?(^container_id, &1.id))

    %{
      container: container,
      device: device,
      deployment: deployment,
      # Needed for container_instance identity
      container_id: container.id,
      device_id: device.id,
      env: Map.get(config, :env),
      env_strategy: Map.get(config, :env_strategy),
      file_binds: Map.get(config, :file_binds, [])
    }
  end
end
