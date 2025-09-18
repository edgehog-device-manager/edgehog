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

defmodule Edgehog.Containers.Validations.SameApplication do
  @moduledoc false
  use Ash.Resource.Validation

  alias Edgehog.Containers.Release

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    initial_release = Ash.Changeset.get_data(changeset, :release_id)
    tenant = Ash.Changeset.get_data(changeset, :tenant_id)

    with {:ok, current} <- Ash.get(Release, initial_release, reuse_values?: true, tenant: tenant),
         {:ok, target_id} <- Ash.Changeset.fetch_argument(changeset, :target),
         {:ok, target} <- Ash.get(Release, target_id, reuse_values?: true, tenant: tenant) do
      if current.application_id == target.application_id do
        :ok
      else
        {:error, field: :target, message: "must belong to the same application as the currently installed release."}
      end
    end
  end
end
