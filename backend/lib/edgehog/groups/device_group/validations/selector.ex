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

defmodule Edgehog.Groups.DeviceGroup.Validations.Selector do
  use Ash.Resource.Validation

  alias Edgehog.Selector

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.fetch_change(changeset, :selector) do
      {:ok, selector} when is_binary(selector) ->
        case Selector.parse(selector) do
          {:ok, _ash_expr} ->
            :ok

          {:error, %Selector.Parser.Error{message: message}} ->
            {:error, field: :selector, message: "failed to be parsed with error: " <> message}
        end

      _ ->
        :ok
    end
  end
end
