#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

defmodule Edgehog.Astarte.Cluster.Changes.TrimTrailingSlashFromURL do
  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _ctx) do
    case Ash.Changeset.fetch_change(changeset, :base_api_url) do
      {:ok, url} when is_binary(url) ->
        trimmed_url = String.trim_trailing(url, "/")
        Ash.Changeset.change_attribute(changeset, :base_api_url, trimmed_url)

      _ ->
        changeset
    end
  end
end
