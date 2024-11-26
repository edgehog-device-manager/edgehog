#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Changes.CheckDeployments do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Devices

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context
    deployment = changeset.data

    with {:ok, :created_containers} <- Ash.Changeset.fetch_argument_or_change(changeset, :status),
         {:ok, deployment} <- Ash.load(deployment, :device),
         {:ok, available_deployments_statuses} <-
           Devices.available_deployments(deployment.device, tenant: tenant) do
      deployment_status =
        Enum.find(available_deployments_statuses, &(&1.id == deployment.id))

      if deployment_status do
        changeset
        |> Ash.Changeset.change_attribute(:status, deployment_status.status)
        |> Ash.Changeset.after_transaction(fn _changeset, transaction_result ->
          with {:ok, deployment} <- transaction_result do
            Containers.run_ready_actions(deployment)
          end
        end)
      else
        changeset
      end
    else
      _ ->
        changeset
    end
  end
end
