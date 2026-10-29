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

defmodule Edgehog.Containers.Container.Deployment.Changes.ResolveEnv do
  @moduledoc """
  Resolves the effective `:env` and `:env_strategy` attributes for a container
  deployment by combining the template container's environment variables with
  any deployment-time `:env` and `:env_strategy` overrides.
  """

  use Ash.Resource.Change

  alias Edgehog.Containers.Container.Env

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    with true <- changeset.valid?,
         {:ok, container} <- Ash.Changeset.fetch_argument(changeset, :container) do
      deploy_env = Ash.Changeset.get_argument(changeset, :env) || []
      env_strategy = Ash.Changeset.get_argument(changeset, :env_strategy) || :merge
      resolved = Env.resolve(container.env || [], deploy_env, env_strategy)

      changeset
      |> Ash.Changeset.change_attribute(:env, resolved)
      |> Ash.Changeset.change_attribute(:env_strategy, env_strategy)
    else
      _ -> changeset
    end
  end
end
