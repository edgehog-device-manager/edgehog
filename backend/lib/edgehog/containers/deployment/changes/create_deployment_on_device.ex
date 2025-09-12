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

defmodule Edgehog.Containers.Deployment.Changes.CreateDeploymentOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Error.Changes.InvalidArgument
  alias Edgehog.Containers
  alias Edgehog.Containers.Deployment.Changes.SendDeploymentToDevice
  alias Edgehog.Devices.Device

  require Ash.Query
  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    device_id = Ash.Changeset.get_argument(changeset, :device_id)
    release_id = Ash.Changeset.get_attribute(changeset, :release_id)

    with {:ok, device} <- fetch_device(device_id, tenant),
         {:ok, release} <- fetch_release(release_id, tenant) do
      if can_deploy?(device.system_model, release.system_models),
        do: Ash.Changeset.after_transaction(changeset, &after_transaction/2),
        else: invalid_argument_error(changeset)
    end
  end

  defp after_transaction(_changeset, result) do
    case result do
      {:ok, deployment} -> SendDeploymentToDevice.deploy_resources(deployment, true)
      error -> Logger.error("Failed to create deployment on device: #{inspect(error)}")
    end
  end

  defp invalid_argument_error(changeset) do
    Ash.Changeset.add_error(
      changeset,
      InvalidArgument.exception(
        field: :system_model,
        message: "The device's system model does not match the system model of the application's release."
      )
    )
  end

  defp fetch_device(device_id, tenant) do
    Device
    |> Ash.Query.filter(id == ^device_id)
    |> Ash.Query.load(:system_model)
    |> Ash.read_one(tenant: tenant)
  end

  defp fetch_release(release_id, tenant) do
    Containers.Release
    |> Ash.Query.filter(id == ^release_id)
    |> Ash.Query.load(:system_models)
    |> Ash.read_one(tenant: tenant)
  end

  defp can_deploy?(_device_sm, nil), do: true
  defp can_deploy?(_device_sm, []), do: true
  defp can_deploy?(nil, _release_sms), do: false

  defp can_deploy?(device_sm, release_sms), do: Enum.any?(release_sms, &(device_sm.id == &1.id))
end
