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

defmodule EdgehogWeb.Resolvers.UpdateCampaigns do
  alias Edgehog.UpdateCampaigns
  alias Edgehog.UpdateCampaigns.UpdateChannel

  def find_update_channel(args, _resolution) do
    UpdateCampaigns.fetch_update_channel(args.id)
  end

  def list_update_channels(_args, _resolution) do
    update_channels = UpdateCampaigns.list_update_channels()

    {:ok, update_channels}
  end

  def create_update_channel(args, _resolution) do
    with {:ok, %UpdateChannel{} = update_channel} <- UpdateCampaigns.create_update_channel(args) do
      {:ok, %{update_channel: update_channel}}
    end
  end

  def update_update_channel(args, _resolution) do
    with {:ok, %UpdateChannel{} = update_channel} <-
           UpdateCampaigns.fetch_update_channel(args.update_channel_id),
         {:ok, %UpdateChannel{} = update_channel} <-
           UpdateCampaigns.update_update_channel(update_channel, args) do
      {:ok, %{update_channel: update_channel}}
    end
  end

  def delete_update_channel(args, _resolution) do
    with {:ok, %UpdateChannel{} = update_channel} <-
           UpdateCampaigns.fetch_update_channel(args.update_channel_id),
         {:ok, %UpdateChannel{} = update_channel} <-
           UpdateCampaigns.delete_update_channel(update_channel) do
      {:ok, %{update_channel: update_channel}}
    end
  end
end
