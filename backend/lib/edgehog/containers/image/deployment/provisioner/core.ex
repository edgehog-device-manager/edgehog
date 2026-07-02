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

defmodule Edgehog.Containers.Image.Deployment.Provisioner.Core do
  @moduledoc """
  Provisioner core module.

  This module provides the functions handling the state of the provisioner,
  returning what the provisioner should answer to external users or itself.
  """

  alias Edgehog.Devices

  require Logger

  def send(image_deployment, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    deployment = Keyword.fetch!(opts, :deployment)

    with {:ok, image_deployment} <- Ash.load(image_deployment, [:image, :device], tenant: tenant),
         {:ok, image} <- Map.fetch(image_deployment, :image),
         {:ok, device} <- Map.fetch(image_deployment, :device),
         {:ok, device} <-
           Devices.send_create_image_request(device, image, deployment, tenant: tenant) do
      Logger.info("""
        Image #{image.id} provisioned on device #{device.device_id}. Waiting events
      """)

      :ok
    end
  end
end
