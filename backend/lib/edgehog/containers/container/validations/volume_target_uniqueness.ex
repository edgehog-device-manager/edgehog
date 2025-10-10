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

defmodule Edgehog.Containers.Container.Validations.VolumeTargetUniqueness do
  @moduledoc false
  use Ash.Resource.Validation

  alias Ash.Resource.Validation

  @impl Validation
  def init(opts) do
    {:ok, opts}
  end

  @impl Validation
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :volumes) do
      {:ok, volumes} ->
        volumes_len = Enum.count(volumes)

        if volumes_len ==
             volumes
             |> Enum.map(& &1.target)
             |> Enum.uniq()
             |> Enum.count(),
           do: :ok,
           else: {:error, "Volume target needs to be unique."}

      # If no volumes are specified, we skip the validation
      :error ->
        :ok
    end
  end

  @impl Validation
  def describe(_opts) do
    [
      message: "Volume target needs to be unique.",
      vars: []
    ]
  end
end
