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

defmodule Edgehog.UpdateCampaignsTest do
  use Edgehog.DataCase

  alias Edgehog.UpdateCampaigns

  describe "update_channels" do
    alias Edgehog.UpdateCampaigns.UpdateChannel

    import Edgehog.UpdateCampaignsFixtures

    @invalid_attrs %{handle: nil, name: nil}

    test "list_update_channels/0 returns all update_channels" do
      update_channel = update_channel_fixture()
      assert UpdateCampaigns.list_update_channels() == [update_channel]
    end

    test "get_update_channel!/1 returns the update_channel with given id" do
      update_channel = update_channel_fixture()
      assert UpdateCampaigns.get_update_channel!(update_channel.id) == update_channel
    end

    test "create_update_channel/1 with valid data creates a update_channel" do
      valid_attrs = %{handle: "some handle", name: "some name"}

      assert {:ok, %UpdateChannel{} = update_channel} =
               UpdateCampaigns.create_update_channel(valid_attrs)

      assert update_channel.handle == "some handle"
      assert update_channel.name == "some name"
    end

    test "create_update_channel/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = UpdateCampaigns.create_update_channel(@invalid_attrs)
    end

    test "update_update_channel/2 with valid data updates the update_channel" do
      update_channel = update_channel_fixture()
      update_attrs = %{handle: "some updated handle", name: "some updated name"}

      assert {:ok, %UpdateChannel{} = update_channel} =
               UpdateCampaigns.update_update_channel(update_channel, update_attrs)

      assert update_channel.handle == "some updated handle"
      assert update_channel.name == "some updated name"
    end

    test "update_update_channel/2 with invalid data returns error changeset" do
      update_channel = update_channel_fixture()

      assert {:error, %Ecto.Changeset{}} =
               UpdateCampaigns.update_update_channel(update_channel, @invalid_attrs)

      assert update_channel == UpdateCampaigns.get_update_channel!(update_channel.id)
    end

    test "delete_update_channel/1 deletes the update_channel" do
      update_channel = update_channel_fixture()
      assert {:ok, %UpdateChannel{}} = UpdateCampaigns.delete_update_channel(update_channel)

      assert_raise Ecto.NoResultsError, fn ->
        UpdateCampaigns.get_update_channel!(update_channel.id)
      end
    end

    test "change_update_channel/1 returns a update_channel changeset" do
      update_channel = update_channel_fixture()
      assert %Ecto.Changeset{} = UpdateCampaigns.change_update_channel(update_channel)
    end
  end
end
