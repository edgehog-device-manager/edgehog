#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Deployment.Changes.MaybePublishDeploymentReady do
  @moduledoc """
  If the deployment is ready, it publishes a `deployment_ready` event trough the Edgehogh PubSub
  """
  use Ash.Resource.Change

  alias Edgehog.PubSub

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.load(:is_ready)
    |> Ash.Changeset.after_transaction(fn _changeset, transaction_result ->
      with {:ok, deployment} <- transaction_result,
           {:ok, deployment} <- Ash.load(deployment, :is_ready) do
        if deployment.is_ready,
          do: PubSub.publish!(:deployment_ready, deployment)

        {:ok, deployment}
      end
    end)
  end
end
