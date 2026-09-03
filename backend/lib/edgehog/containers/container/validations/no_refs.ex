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

defmodule Edgehog.Containers.Container.Validations.NoRefs do
  @moduledoc """
  Container validation for deletion.

  This validation ensures that there are no releases or container_deployments
  referencing the container before deleting it.
  """

  use Ash.Resource.Validation

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    container = Ash.load!(changeset.data, [:releases, :container_deployments])

    with :ok <- no_releases(container.releases),
         do: no_container_deployments(container.container_deployments)
  end

  defp no_releases([]), do: :ok

  defp no_releases(_),
    do: {:error, message: "The container cannot be deleted. Some releases reference it."}

  defp no_container_deployments([]), do: :ok

  defp no_container_deployments(_),
    do: {:error, message: "The container cannot be deleted. It is deployed on some devices."}
end
