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

defmodule Edgehog.Containers.Deployment.Validations.DeviceIsCompatible do
  @moduledoc false
  use Ash.Resource.Validation

  alias Ash.Error.Changes.InvalidArgument
  alias Edgehog.Containers
  alias Edgehog.Devices

  require Ash.Query

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant}) do
    device_id = Ash.Changeset.get_argument(changeset, :device_id)
    release_id = Ash.Changeset.get_attribute(changeset, :release_id)

    with {:ok, device} <- fetch_device(device_id, tenant),
         {:ok, release} <- fetch_release(release_id, tenant) do
      if can_deploy?(device.system_model, release.system_models),
        do: :ok,
        else: {:error, invalid_argument_error(changeset)}
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
    Devices.fetch_device(device_id, tenant: tenant, load: :system_model)
  end

  defp fetch_release(release_id, tenant) do
    Containers.fetch_release(release_id, tenant: tenant, load: :system_models)
  end

  defp can_deploy?(_device_sm, nil), do: true
  defp can_deploy?(_device_sm, []), do: true
  defp can_deploy?(nil, _release_sms), do: false

  defp can_deploy?(device_sm, release_sms), do: Enum.any?(release_sms, &(device_sm.id == &1.id))
end
