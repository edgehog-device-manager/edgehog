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

defmodule Edgehog.Containers.Release.Deployment.Changes.CreateDeploymentOnDevice do
  @moduledoc false
  use Ash.Resource.Change

  alias Edgehog.Containers

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    # After the transaction has been executed, i.e. all checks have passed
    # and the deployment is in the data layer, start the deployment with
    # the result.
    Ash.Changeset.after_action(changeset, fn _changeset, deployment ->
      with :ok <- Containers.send_deploy_request(deployment) do
        {:ok, deployment}
      end
    end)
  end
end
