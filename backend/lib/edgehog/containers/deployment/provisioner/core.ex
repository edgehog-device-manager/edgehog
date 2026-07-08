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

defmodule Edgehog.Containers.Deployment.Provisioner.Core do
  @moduledoc """
  Deployment provisioner core functions.
  """

  alias Edgehog.Devices

  require Logger

  def send(deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:ok, deployment} <- Ash.load(deployment, :device, tenant: tenant),
         device = deployment.device,
         {:ok, device} <-
           Devices.send_create_deployment_request(device, deployment, tenant: tenant) do
      deployment
      |> Ash.Changeset.for_update(:mark_as_sent, %{}, tenant: tenant)
      |> Ash.update!()

      Logger.info("""
        Deployment #{deployment.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end
end
