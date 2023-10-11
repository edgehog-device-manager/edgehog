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
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  @type event :: :ota_operation_created | :ota_operation_updated | :update_campaign_updated

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

  def publish!(:update_campaign_updated = event, %UpdateCampaign{} = update_campaign) do
    payload = {event, update_campaign}
    topics = [topic_for_subject(update_campaign)]

    broadcast_many!(topics, payload)
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
  defp topic_for_subject(%UpdateCampaign{id: id}), do: "update_campaigns:#{id}"
  defp topic_for_subject({:update_campaign, id}), do: "update_campaigns:#{id}"
end
