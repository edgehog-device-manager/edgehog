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

defmodule Edgehog.Containers.Container.Deployment.Validations.EnvOrEnvFile do
  @moduledoc """
  Ensures that a container deployment does not have both additional env vars and env files.
  At most one of `env` and `env_files` may be set; setting both is ambiguous.
  `none` (both empty) is allowed to inherit the image defaults.
  """

  use Ash.Resource.Validation

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    env = Ash.Changeset.get_argument(changeset, :env) || []
    env_files = Ash.Changeset.get_argument(changeset, :env_files) || []

    has_env? = not Enum.empty?(env)
    has_env_files? = not Enum.empty?(env_files)

    if has_env? and has_env_files? do
      {:error,
       field: :env, message: "cannot set both env vars and env files; pick one mode (or none)"}
    else
      :ok
    end
  end
end
