#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.Astarte.Cluster.Validations.URL do
  @moduledoc false
  use Ash.Resource.Validation

  alias Ash.Resource.Validation

  @impl Validation
  def init(opts) do
    if is_atom(opts[:attribute]) do
      {:ok, opts}
    else
      {:error, "attribute must be an atom"}
    end
  end

  @impl Validation
  def validate(changeset, opts, _context) do
    case Ash.Changeset.fetch_argument_or_change(changeset, opts[:attribute]) do
      {:ok, url} when is_binary(url) ->
        %URI{scheme: scheme, host: maybe_host} = URI.parse(url)

        host = to_string(maybe_host)
        empty_host? = host == ""
        space_in_host? = host =~ " "

        valid_host? = not empty_host? and not space_in_host?
        valid_scheme? = scheme in ["http", "https"]

        if valid_host? and valid_scheme? do
          :ok
        else
          {:error, field: opts[:attribute], message: "is not a valid URL"}
        end

      _ ->
        :ok
    end
  end
end
