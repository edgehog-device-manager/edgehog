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

defmodule Edgehog.Campaigns.CampaignMechanism.Helpers do
  @moduledoc """
  Shared helper functions for campaign mechanism implementations.

  This module provides common functionality used across different campaign mechanisms,
  including deployment operations, timeout handling, and notification processing.
  """

  alias Edgehog.Campaigns
  alias Edgehog.Containers

  @doc """
  Checks if an application is deployed on the target device for a given release.

  ## Parameters
    - target: The deployment target struct.
    - release: The release struct to check.

  ## Returns
    - `true` if the deployment exists.
    - `false` if the deployment does not exist.
    - Raises an error for unexpected failures.
  """
  def application_deployed?(target, release) do
    device =
      target
      |> Ash.load!(:device)
      |> Map.get(:device)

    case Containers.deployment_by_identity(device.id, release.id, tenant: target.tenant_id) do
      {:ok, _deployment} ->
        true

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} ->
        false

      {:error, other_reason} ->
        raise other_reason
    end
  end

  @doc """
  Links a target to its deployment based on device and release.

  ## Parameters
    - target: The deployment target struct.
    - release: The release struct.

  ## Returns
    - `{:ok, updated_target}` with the deployment linked.
  """
  def link_target_deployment(target, release) do
    device =
      target
      |> Ash.load!(:device)
      |> Map.get(:device)

    {:ok, deployment} =
      Containers.deployment_by_identity(device.id, release.id, tenant: target.tenant_id)

    Campaigns.set_target_deployment(target, deployment.id, tenant: target.tenant_id)
  end

  @doc """
  Retries a target operation by executing the specified update action on the deployment.

  ## Parameters
    - target: The deployment target struct.
    - update_action: The action atom to execute (e.g., :start, :stop, :delete, :send_deployment).

  ## Returns
    - `:ok` if the retry is successful.
    - `{:error, reason}` if the retry fails.
  """
  def do_retry_target_operation(target, update_action) do
    deployment_result =
      target
      |> Ash.load!(:deployment, tenant: target.tenant_id)
      |> Map.get(:deployment)
      |> Ash.Changeset.for_update(update_action)
      |> Ash.update(tenant: target.tenant_id)

    with {:ok, _deployment} <- deployment_result do
      :ok
    end
  end
end
