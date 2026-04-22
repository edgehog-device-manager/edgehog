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

defmodule Edgehog.Files.FileDownloadRequest.Validations.FileExists do
  @moduledoc false

  use Ash.Resource.Validation

  alias Ash.Resource.Validation

  @impl Validation
  def validate(changeset, _opts, %{tenant: tenant} = _context) do
    file_id = Ash.Changeset.get_argument(changeset, :file_id)

    with {:ok, _file} <- Ash.get(Edgehog.Files.File, file_id, tenant: tenant) do
      :ok
    end
  end

  @impl Validation
  def batch_callbacks?(_changeset, _opts, _context), do: false

  @impl Validation
  def has_batch_validate?, do: false
end
