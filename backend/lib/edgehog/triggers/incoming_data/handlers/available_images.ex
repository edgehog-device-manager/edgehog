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

defmodule Edgehog.Triggers.IncomingData.Handlers.AvailableImages do
  @moduledoc """
  Available Images handler
  """
  @behaviour Ash.Astarte.Triggers.HandlerBehavior

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Astarte.Triggers.HandlerBehavior
  def handle_event(event, _opts, context) do
    %{realm_id: realm_id, device_id: device_id, tenant: tenant} = context

    device = Devices.fetch_device_by_identity!(device_id, realm_id, tenant: tenant)

    case String.split(event.path, "/") do
      ["", image_id, "pulled"] ->
        handle_pulled(image_id, event.value, device.id, tenant)

      ["", image_id, "status"] ->
        update_image_deployment(image_id, device.id, %{status: event.value}, tenant)

      ["", image_id, "imageId"] ->
        update_image_deployment(image_id, device.id, %{docker_image_id: event.value}, tenant)

      ["", image_id, "repoTags"] ->
        update_image_deployment(image_id, device.id, %{repo_tags: event.value}, tenant)

      ["", image_id, "repoDigests"] ->
        update_image_deployment(image_id, device.id, %{repo_digests: event.value}, tenant)

      ["", image_id, "size"] ->
        update_image_deployment(image_id, device.id, %{size: event.value}, tenant)

      _ ->
        {:error, :invalid_event_path}
    end
  end

  defp handle_pulled(image_id, value, device_id, tenant) do
    image_deployment =
      Containers.fetch_image_deployment!(image_id, device_id, tenant: tenant)

    case value do
      true ->
        Containers.mark_image_deployment_as_pulled(image_deployment, tenant: tenant)

      false ->
        Containers.mark_image_deployment_as_unpulled(image_deployment, tenant: tenant)

      nil ->
        Containers.destroy_image_deployment!(image_deployment, tenant: tenant)
        {:ok, image_deployment}
    end
  end

  defp update_image_deployment(image_id, device_id, attrs, tenant) do
    case Containers.fetch_image_deployment(image_id, device_id, tenant: tenant) do
      {:ok, image_deployment} ->
        Containers.update_image_deployment_from_device(image_deployment, attrs, tenant: tenant)

      {:error, _reason} = error ->
        if attrs |> Map.values() |> Enum.all?(&is_nil/1), do: :ok, else: error
    end
  end
end
