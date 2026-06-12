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

defmodule Edgehog.Containers.Release.Validations.CheckDeployments do
  @moduledoc false

  use Ash.Resource.Validation

  require Ash.Query

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant}) do
    id = Ash.Changeset.get_data(changeset, :id)
    version = Ash.Changeset.get_data(changeset, :version)

    deployed? =
      Edgehog.Containers.Deployment
      |> Ash.Query.filter(release_id: id)
      |> Ash.exists?(tenant: tenant)

    if deployed?,
      do: {:error, message: "Release with version #{version} has active deployments."},
      else: :ok
  end
end
