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

defmodule Edgehog.Containers.Container.Changes.DeployContainerOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Devices

  require Logger

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    device = Ash.Changeset.get_argument(changeset, :device)
    container = Ash.Changeset.get_argument(changeset, :container)
    deployment = Ash.Changeset.get_argument(changeset, :deployment)

    Ash.Changeset.after_transaction(changeset, fn _changeset, {:ok, container_deployment} ->
      case Devices.send_create_container_request(device, container, deployment) do
        {:ok, _device} ->
          Containers.mark_container_deployment_as_sent(container_deployment)

        # TODO: instead of destroying the container deployment, we should retry
        # sending the request after a delay.
        {:error, reason} ->
          Logger.warning("Failed to send container deployment request: #{inspect(reason)}")
          :ok = Containers.destroy_container_deployment(container_deployment, tenant: tenant)
          {:error, reason}
      end
    end)
  end
end
