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

defmodule Edgehog.UpdateCampaigns.Target do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Devices
  alias Edgehog.UpdateCampaigns.UpdateCampaign

  schema "update_campaign_targets" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :status, Ecto.Enum, values: [:idle, :pending, :failed, :successful]
    field :retry_count, :integer, default: 0
    field :latest_attempt, :utc_datetime_usec
    field :ota_operation_id, :binary_id
    field :completion_timestamp, :utc_datetime_usec
    belongs_to :update_campaign, UpdateCampaign
    belongs_to :device, Devices.Device

    timestamps()
  end

  @doc false
  def changeset(target, attrs) do
    target
    |> cast(attrs, [:status])
    |> validate_required([:status])
  end
end
