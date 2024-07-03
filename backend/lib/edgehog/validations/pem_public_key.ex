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

defmodule Edgehog.Validations.PEMPublicKey do
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
      {:ok, nil} ->
        :ok

      {:ok, changing_to} when is_binary(changing_to) ->
        case X509.PublicKey.from_pem(changing_to) do
          {:ok, _} ->
            :ok

          {:error, _reason} ->
            {:error, field: opts[:attribute], message: "is not a valid PEM public key"}
        end

      _ ->
        :ok
    end
  end
end
