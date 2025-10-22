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

defmodule Edgehog.Containers.Container.Validations.BindsFormat do
  @moduledoc false
  use Ash.Resource.Validation

  alias Ash.Resource.Validation

  @impl Validation
  def init(opts) do
    {:ok, opts}
  end

  @impl Validation
  def validate(changeset, _opts, _context) do
    binds = Ash.Changeset.get_attribute(changeset, :binds) || []

    if Enum.all?(binds, &valid_bind?/1) do
      :ok
    else
      {:error, "Each bind must follow the format host-path:container-path[:options]"}
    end
  end

  @impl Validation
  def describe(_opts) do
    [
      message: "Each bind must follow the format host-path:container-path[:options]",
      vars: []
    ]
  end

  defp valid_bind?(bind) when is_binary(bind) do
    case String.split(bind, ":") do
      [source, target] when source != "" and target != "" -> true
      [source, target, options] when source != "" and target != "" and options != "" -> true
      _ -> false
    end
  end

  defp valid_bind?(_), do: false
end
