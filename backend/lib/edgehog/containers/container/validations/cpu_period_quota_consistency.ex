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

defmodule Edgehog.Containers.Container.Validations.CpuPeriodQuotaConsistency do
  @moduledoc false
  use Ash.Resource.Validation

  alias Ash.Resource.Validation

  @impl Validation
  def init(opts) do
    {:ok, opts}
  end

  @impl Validation
  def validate(changeset, _opts, _context) do
    cpu_period = Ash.Changeset.get_argument_or_attribute(changeset, :cpu_period)
    cpu_quota = Ash.Changeset.get_argument_or_attribute(changeset, :cpu_quota)

    case {cpu_period, cpu_quota} do
      # Both unset (default value nil)
      {nil, nil} ->
        :ok

      # Both set (not nil)
      {p, q} when p != nil and q != nil ->
        :ok

      # One set, one unset - invalid
      _ ->
        {:error, "CPU period and CPU quota must be either both set or both unset"}
    end
  end

  @impl Validation
  def describe(_opts) do
    [
      message: "CPU period and CPU quota must be either both set or both unset",
      vars: []
    ]
  end
end
