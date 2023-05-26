#
# This file is part of Edgehog.
#
# Copyright 2022-2023 SECO Mind Srl
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

defmodule Edgehog.OSManagement.OTAOperation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Edgehog.Devices

  @statuses [
    pending: "Pending",
    acknowledged: "Acknowledged",
    downloading: "Downloading",
    deploying: "Deploying",
    deployed: "Deployed",
    rebooting: "Rebooting",
    error: "Error",
    failure: "Failure",
    success: "Success"
  ]

  @status_codes [
    request_timeout: "RequestTimeout",
    invalid_request: "InvalidRequest",
    update_already_in_progress: "UpdateAlreadyInProgress",
    network_error: "NetworkError",
    io_error: "IOError",
    internal_error: "InternalError",
    invalid_base_image: "InvalidBaseImage",
    system_rollback: "SystemRollback",
    canceled: "Canceled"
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "ota_operations" do
    field :base_image_url, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :status_code, Ecto.Enum, values: @status_codes
    field :status_progress, :integer, default: 0
    field :message, :string
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :manual?, :boolean, source: :is_manual, default: false
    belongs_to :device, Devices.Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def create_changeset(ota_operation, attrs) do
    ota_operation
    |> cast(attrs, [:base_image_url, :status, :status_code, :status_progress, :message])
    |> validate_required([:base_image_url])
  end

  @doc false
  def update_changeset(ota_operation, attrs) do
    ota_operation
    |> cast(attrs, [:status, :status_code, :status_progress, :message])
  end

  @doc """
  Returns true if this state is considered final, i.e. the OTA Operation is
  considered finished and is not expected to do any other progress
  """
  def final_state?(:success), do: true
  def final_state?(:failure), do: true
  def final_state?(_other), do: false
end
