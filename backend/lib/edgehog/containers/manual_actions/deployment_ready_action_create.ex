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

defmodule Edgehog.Containers.ManualActions.DeploymentReadyActionAddRelationship do
  @moduledoc false

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :action_arguments) do
      {:ok, arguments} ->
        case Ash.Changeset.fetch_change(changeset, :action_type) do
          {:ok, action_type} ->
            # The relationship has the same name as the action type
            Ash.Changeset.manage_relationship(changeset, action_type, arguments, type: :create)

          :error ->
            Ash.Changeset.add_error(changeset, field: :action_type, message: "must not be nil")
        end

      :error ->
        changeset
    end
  end
end
