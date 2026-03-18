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

defmodule Edgehog.Files.File.Validations.RepositoryExists do
  @moduledoc false

  use Ash.Resource.Validation

  alias Ash.Resource.Validation

  @impl Validation
  def supports(_opts), do: [Ash.ActionInput]

  @impl Validation
  def validate(action_input, _opts, %{tenant: tenant} = _context) do
    repository_id = action_input.arguments.repository_id

    with {:ok, _repository} <- Ash.get(Edgehog.Files.Repository, repository_id, tenant: tenant) do
      :ok
    end
  end
end
