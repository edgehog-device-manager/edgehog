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

defmodule Edgehog.Containers.Deployment.Core do
  @moduledoc false
  alias Astarte.Client.APIError
  alias Edgehog.Containers
  alias Edgehog.Devices

  @doc """
  Returns a printable error message given an error reason
  """
  def error_message(_) do
    ""
  end

  @doc """
  Returns the release with the given id if prsent, `nil` otherwise.
  """
  def fetch_release!(tenant_id, release_id) do
    Containers.fetch_release!(release_id, tenant: tenant_id)
  end

  @doc """
  Returns the device with the given id if prsent, `nil` otherwise.
  """
  def fetch_device!(tenant_id, device_id) do
    Devices.fetch_device!(device_id, tenant: tenant_id)
  end

  @doc """
  Returns a :queue of containers and one of images from a release
  """
  def containers_and_images_from_release(release) do
    images = Enum.map(release.containers, & &1.image)
    {:queue.from_list(release.containers), :queue.from_list(images)}
  end

  @doc """
  Pops an element from a queue.
  """
  def queue_pop(queue) do
    case :queue.out(queue) do
      {:empty, _} -> :empty
      {{:value, head}, tail} -> {head, tail}
    end
  end

  @doc """
  Pushes an element on the back of a queue, building a new queue
  """
  def queue_push(queue, value) do
    :queue.in(queue, value)
  end

  @doc """
  Send a create image request.
  """
  def send_create_image(tenant_id, image, device, image_credentials \\ nil) do
    Devices.send_create_image_request(device, image, image_credentials, tenant: tenant_id)
  end

  @doc """
  Returns `true` if the error indicated by `reason` is considered temporary.
  For now we assume only failures to reach Astarte and server errors are temporary.
  """
  def temporary_error?("connection refused"), do: true
  def temporary_error?(%APIError{status: status}) when status in 500..599, do: true
  def temporary_error?(_reason), do: false
end
