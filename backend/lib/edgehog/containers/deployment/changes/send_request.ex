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

defmodule Edgehog.Containers.Deployment.Changes.SendRequest do
  @moduledoc """
  Automatically update the deployment and send the requests to the device once
  the database transaction is clsed and all the resources are available.
  """
  use Ash.Resource.Change

  alias Edgehog.Containers

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, deployment} <- result do
        Containers.send_deployment(deployment, tenant: tenant)
      end
    end)
  end
end
