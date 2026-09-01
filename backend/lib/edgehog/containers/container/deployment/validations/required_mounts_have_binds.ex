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

defmodule Edgehog.Containers.Container.Deployment.Validations.RequiredMountsHaveBinds do
  @moduledoc """
  When creating a container deployment, ensures that required file mounts have a referencing file bind.
  """

  use Ash.Resource.Validation

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    required_file_mounts =
      changeset
      |> Ash.Changeset.get_argument(:container)
      |> Ash.load!(:file_mounts)
      |> Map.fetch!(:file_mounts)
      |> Enum.filter(& &1.required)

    assoc_file_mounts =
      changeset
      |> Ash.Changeset.get_argument(:file_binds)
      |> Enum.map(& &1.file_mount_id)

    required_ok? = Enum.all?(required_file_mounts, &(&1.id in assoc_file_mounts))

    if required_ok?,
      do: :ok,
      else: {:error, field: :file_binds, message: "Some required mountpoints are not being set."}
  end
end
