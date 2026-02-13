# This file is part of Edgehog.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Edgehog.BaseImages.BaseImage.Validations.BaseImageNotInUse do
  @moduledoc false
  use Ash.Resource.Validation

  alias Edgehog.Campaigns.Campaign

  require Ash.Query

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, %{tenant: tenant}) do
    resource = changeset.data

    campaigns =
      Campaign
      |> Ash.Query.for_read(:read, %{}, tenant: tenant)
      |> Ash.Query.filter(
        fragment(
          "(?->>'type') = ? AND (?->>'base_image_id')::int = ?",
          campaign_mechanism,
          "firmware_upgrade",
          campaign_mechanism,
          ^resource.id
        )
      )
      |> Ash.Query.filter(status != :finished)
      |> Ash.Query.limit(1)
      |> Ash.read!()

    case campaigns do
      [] ->
        :ok

      [_] ->
        campaign_names = Enum.map_join(campaigns, ", ", & &1.name)

        {:error,
         field: :id, message: "Base image is currently in use by the following running campaigns: #{campaign_names}"}
    end
  end
end
