#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Changes.MaybeHandleReadiness do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers
  alias Edgehog.Containers.Deployment

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, transaction_result ->
      with {:ok, deployment} <- transaction_result,
           {:ok, deployment} <- Ash.load(deployment, :is_ready),
           do: maybe_run_ready_actions(deployment)
    end)
  end

  defp maybe_run_ready_actions(%Deployment{is_ready: true} = deployment) do
    Ash.Notifier.notify(%Ash.Notifier.Notification{
      data: deployment,
      for: [Ash.Notifier.PubSub],
      action: %{type: :update, name: :maybe_run_ready_actions},
      resource: Deployment,
      metadata: %{custom_event: :deployment_ready}
    })

    Containers.run_ready_actions(deployment)
  end

  defp maybe_run_ready_actions(deployment), do: {:ok, deployment}
end
