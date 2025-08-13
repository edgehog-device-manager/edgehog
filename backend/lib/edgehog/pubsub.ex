#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.PubSub do
  @moduledoc """
  This module implements a PubSub system for events happening inside Edgehog
  """

  alias Edgehog.OSManagement.OTAOperation

  @type event ::
          :ota_operation_created
          | :ota_operation_updated
          | :available_image
          | :available_network
          | :available_volume
          | :available_container
          | :available_deployment

  @doc """
  Publish an event to the PubSub. Raises if any of the publish fails.
  """
  @spec publish!(event :: event(), subject :: any) :: :ok | {:error, reason :: any()}
  def publish!(event, subject)

  def publish!(:ota_operation_created = event, %OTAOperation{} = ota_operation) do
    payload = {event, ota_operation}
    topics = [wildcard_topic_for_subject(ota_operation)]

    broadcast_many!(topics, payload)
  end

  def publish!(:ota_operation_updated = event, %OTAOperation{} = ota_operation) do
    payload = {event, ota_operation}

    topics = [
      topic_for_subject(ota_operation),
      wildcard_topic_for_subject(ota_operation)
    ]

    broadcast_many!(topics, payload)
  end

  def publish!(:available_image = event, image_deployment_details) do
    image_id = Keyword.fetch!(image_deployment_details, :image_id)
    payload = {event, image_id}

    topics = [topic_for_subject(image_deployment_details)]

    broadcast_many!(topics, payload)
  end

  def publish!(:available_network = event, network_deployment_details) do
    network_id = Keyword.fetch!(network_deployment_details, :network_id)
    payload = {event, network_id}

    topics = [topic_for_subject(network_deployment_details)]

    broadcast_many!(topics, payload)
  end

  def publish!(:available_volume = event, volume_deployment_details) do
    volume_id = Keyword.fetch!(volume_deployment_details, :volume_id)
    payload = {event, volume_id}

    topics = [topic_for_subject(volume_deployment_details)]

    broadcast_many!(topics, payload)
  end

  def publish!(:available_container = event, container_deployment_details) do
    container_id = Keyword.fetch!(container_deployment_details, :container_id)
    payload = {event, container_id}

    topics = [topic_for_subject(container_deployment_details)]

    broadcast_many!(topics, payload)
  end

  def publish!(:available_deployment = event, deployment_details) do
    topics = [topic_for_subject(deployment_details)]

    broadcast_many!(topics, event)
  end

  defp broadcast_many!(topics, payload) do
    Enum.each(topics, fn topic ->
      Phoenix.PubSub.broadcast!(Edgehog.PubSub, topic, payload)
    end)
  end

  @doc """
  Subscribe to events for a specific subject.
  """
  def subscribe_to_events_for(subject) do
    topic = topic_for_subject(subject)

    Phoenix.PubSub.subscribe(Edgehog.PubSub, topic)
  end

  defp wildcard_topic_for_subject(subject)
  defp wildcard_topic_for_subject(%OTAOperation{}), do: topic_for_subject(:ota_operations)

  defp topic_for_subject(subject)
  defp topic_for_subject(%OTAOperation{id: id}), do: "ota_operations:#{id}"
  defp topic_for_subject({:ota_operation, id}), do: "ota_operations:#{id}"
  defp topic_for_subject(:ota_operations), do: "ota_operations:*"

  defp topic_for_subject(image_id: image_id, device_id: device_id, tenant: tenant),
    do: "image_deployment:#{image_id}:#{device_id}:#{tenant}"

  defp topic_for_subject(network_id: network_id, device_id: device_id, tenant: tenant),
    do: "network_deployment:#{network_id}:#{device_id}:#{tenant}"

  defp topic_for_subject(volume_id: volume_id, device_id: device_id, tenant: tenant),
    do: "volume_deployment:#{volume_id}:#{device_id}:#{tenant}"

  defp topic_for_subject(container_id: container_id, device_id: device_id, tenant: tenant),
    do: "container_deployment:#{container_id}:#{device_id}:#{tenant}"

  defp topic_for_subject(deployment_id: deployment_id, tenant: tenant), do: "deployment:#{deployment_id}:#{tenant}"
end
