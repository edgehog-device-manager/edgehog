#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Containers.Volume.Deployment.Provisioner.Core do
  @moduledoc """
  Volume deployment core functions

  This module contains all functions required by the provisioner that handle the business logic
  e.g., sending data to the device
  """

  alias Edgehog.Devices

  require Logger

  def send(volume_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, volume_deployment} <-
           Ash.load(volume_deployment, [:volume, :device], tenant: tenant),
         {:ok, volume} <- Map.fetch(volume_deployment, :volume),
         {:ok, device} <- Map.fetch(volume_deployment, :device),
         {:ok, device} <-
           Devices.send_create_volume_request(device, volume, deployment, tenant: tenant) do
      Logger.info("""
        Volume #{volume.id} sent to device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end
end
