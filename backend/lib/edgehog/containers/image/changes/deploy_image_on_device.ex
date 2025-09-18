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

defmodule Edgehog.Containers.Image.Changes.DeployImageOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Devices

  require Logger

  @impl Ash.Resource.Change
  @spec change(Ash.Changeset.t(), any(), %{:tenant => any(), optional(any()) => any()}) ::
          Ash.Changeset.t()
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context
    image = Ash.Changeset.get_argument(changeset, :image)
    device = Ash.Changeset.get_argument(changeset, :device)
    deployment = Ash.Changeset.get_argument(changeset, :deployment)

    Ash.Changeset.after_transaction(changeset, fn _changeset, {:ok, image_deployment} ->
      case Devices.send_create_image_request(device, image, deployment, tenant: tenant) do
        {:ok, _device} ->
          Containers.mark_image_deployment_as_sent(image_deployment)

        # TODO: instead of destroying the image deployment, we should retry
        # sending the request after a delay.
        {:error, reason} ->
          Logger.warning("Failed to send image deployment request: #{inspect(reason)}")
          :ok = Containers.destroy_image_deployment(image_deployment, tenant: tenant)
          {:error, reason}
      end
    end)
  end
end
