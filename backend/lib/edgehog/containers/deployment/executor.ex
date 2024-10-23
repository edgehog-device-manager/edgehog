#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Executor do
  @moduledoc false
  use GenServer

  alias Edgehog.Devices

  def start(opts) do
    GenServer.start(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    deployment = Keyword.get(opts, :deployment)

    with {:ok, deployment} <-
           Ash.load(deployment, release: [containers: [image: [:credentials]]]),
         {:ok, deployment} <- Ash.load(deployment, :device) do
      release = deployment.release
      device = deployment.device

      containers = release.containers
      images = Enum.map(containers, & &1.image)
      {:ok, %{containers: containers, images: images, device: device}}
    end
  end

  @impl GenServer
  def handle_call(:deploy, _from, state) do
    %{
      containers: containers,
      images: images
    } = state

    with :ok <- send_images(images),
         :ok <- send_containers(containers) do
      {:reply, :ok, state}
    end
  end

  defp send_images(images) do
    _res = Enum.map(images, &GenServer.cast(__MODULE__, {:send_image, &1}))
    :ok
  end

  defp send_containers(containers) do
    _res = Enum.map(containers, &GenServer.cast(__MODULE__, {:send_container, &1}))
    :ok
  end

  @impl GenServer
  def handle_cast({:send_image, image}, state) do
    %{device: device} = state
    _res = Devices.send_create_image_request(device, image, image.credentials)

    {:noreply, state}
  end

  def handle_cast({:send_container, container}, state) do
    %{device: device} = state
    _res = Devices.send_create_container_request(device, container)
    {:noreply, state}
  end
end
