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

defmodule Edgehog.Containers.Release.Deployment.Changes.SendUpgrade do
  @moduledoc """
  A change to upgrade the deployment of an application to a newer version.

  This ensures that the communication with the device happens only when the
  database has been updated with relevant information _and_ in case of success
  """
  use Ash.Resource.Change
  alias Edgehog.Containers.Release.Deployment
  alias Edgehog.Containers.Release.Deployment.ReadyAction

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    changeset
    |> Ash.Changeset.after_action(&register_ready_action(&1, &2, tenant))
    |> Ash.Changeset.after_transaction(&start_supervisor(&1, &2, tenant))
  end

  defp register_ready_action(changeset, deployment, tenant) do
    device_id = deployment.device_id
    # SAFETY: we have validated the parameter in the validations, so it must exist.
    target_id = Ash.Changeset.get_argument(changeset, :target)
    configs = Ash.Changeset.get_argument(changeset, :configs) || []

    with {:ok, action} <-
           ReadyAction
           |> Ash.Changeset.for_create(
             :create_deployment,
             %{
               deployment: %{device_id: device_id, release_id: target_id, configs: configs},
               action_type: :upgrade_deployment,
               action_arguments: %{upgrade_target_id: deployment.id}
             }
           )
           |> Ash.create(tenant: tenant) do
      {:ok, action.deployment}
    end
  end

  defp start_supervisor(_changeset, {:ok, new_deployment}, tenant) do
    new_deployment = Ash.load!(new_deployment, :tenant, tenant: tenant)

    case Deployment.Orchestrator.conduct(new_deployment, new_deployment.tenant) do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, new_deployment}
    end
  end

  defp start_supervisor(_changeset, error, _tenant), do: error
end
