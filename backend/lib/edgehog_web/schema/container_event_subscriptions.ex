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

defmodule EdgehogWeb.Schema.ContainerEventSubscriptions do
  @moduledoc false
  use Absinthe.Schema.Notation

  alias AshGraphql.Resource, as: AshGraphqlResource
  alias AshGraphql.Resource.Info, as: AshGraphqlResourceInfo
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.EnvFile
  alias Edgehog.Containers.FileBind
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Volume

  union :release_deployment_event_payload do
    description "An event occurring on a release deployment or any of its child container resources."

    types [
      :deployment_event,
      :container_deployment_event,
      :image_deployment_event,
      :volume_deployment_event,
      :network_deployment_event,
      :env_file_event,
      :file_bind_event
    ]

    resolve_type &resolve_event_type/2
  end

  union :container_deployment_event_payload do
    description "An event occurring on a container deployment or any of its child resources."

    types [
      :container_deployment_event,
      :image_deployment_event,
      :volume_deployment_event,
      :network_deployment_event,
      :env_file_event,
      :file_bind_event
    ]

    resolve_type &resolve_event_type/2
  end

  object :container_event_subscriptions do
    @desc "Subscribes to events for a release deployment and all of its child container resources."
    field :release_deployment_events, :release_deployment_event_payload do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(Release.Deployment, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a container deployment and all of its child resources."
    field :container_deployment_events, :container_deployment_event_payload do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(Container.Deployment, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for an image deployment."
    field :image_deployment_events, :image_deployment_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(Image.Deployment, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a volume deployment."
    field :volume_deployment_events, :volume_deployment_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(Volume.Deployment, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a network deployment."
    field :network_deployment_events, :network_deployment_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(Network.Deployment, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for an env file deployment."
    field :env_file_deployment_events, :env_file_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(EnvFile, args, resolution)
      end

      resolve &resolve_event/3
    end

    @desc "Subscribes to events for a file bind deployment."
    field :file_bind_deployment_events, :file_bind_event do
      arg :id, non_null(:id)

      config fn args, resolution ->
        subscribe_to_resource(FileBind, args, resolution)
      end

      resolve &resolve_event/3
    end
  end

  defp resolve_event_type(%{__type__: type}, _), do: type
  defp resolve_event_type(_, _), do: nil

  defp resolve_event({:pre_resolved, item}, _args, _resolution), do: {:ok, item}

  defp resolve_event([first], _args, _resolution), do: {:ok, first}

  defp resolve_event([first | rest], _args, _resolution) do
    Process.put(:batch_resolved, rest)
    {:ok, first}
  end

  defp resolve_event(event, _args, _resolution), do: {:ok, event}

  defp subscribe_to_resource(resource_module, %{id: id}, %{context: context}) do
    with %{tenant_id: tenant_id} <- context[:tenant] || context[:current_tenant],
         {:ok, resource_uuid} <- extract_uuid(resource_module, id) do
      {:ok, topic: "#{tenant_id}:#{resource_uuid}"}
    else
      _ -> {:error, "Invalid resource ID"}
    end
  end

  defp extract_uuid(resource_module, id) when is_binary(id) do
    expected_type = AshGraphqlResourceInfo.type(resource_module)

    case AshGraphqlResource.decode_relay_id(id) do
      {:ok, %{type: ^expected_type, id: decoded_id}} ->
        Ecto.UUID.cast(decoded_id)

      {:ok, %{type: _other_type}} ->
        :error

      {:error, _} ->
        Ecto.UUID.cast(id)
    end
  end

  defp extract_uuid(_resource_module, _id), do: :error
end
