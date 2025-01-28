#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.Changes.CreateDefaultNetwork do
  @moduledoc false
  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _ctx) do
    default_network_parameters = %{
      driver: "bridge",
      options: %{"isolate" => "true"},
      internal: true,
      enable_ipv6: false
    }

    Ash.Changeset.manage_relationship(changeset, :networks, default_network_parameters, type: :create)
  end
end
