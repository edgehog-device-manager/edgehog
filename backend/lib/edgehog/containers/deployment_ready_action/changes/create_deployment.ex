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

defmodule Edgehog.Containers.DeploymentReadyAction.Changes.CreateDeployment do
  @moduledoc """
  Ash change for deployment ready action that creates the target deployment.

  Provisioning is inhibited here, as it is triggered by the `run` action.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    input = Ash.Changeset.get_argument(changeset, :deployment)

    changeset
    |> Ash.Changeset.set_context(%{shared: %{run_provisioner: false}})
    |> Ash.Changeset.manage_relationship(:deployment, input,
      on_lookup: :relate,
      use_identities: [:_primary_key, :release_instance],
      on_no_match: {:create, :deploy},
      on_match: :ignore
    )
  end
end
