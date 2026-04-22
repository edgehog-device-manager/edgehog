#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Campaigns.CampaignTarget.Changes.CreateManagedOTAOperation do
  @moduledoc """
  An Ash change that creates a managed OTA operation for the target device.
  This change fetches the base image from the arguments and creates an OTA operation
  associated with the target device.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case Ash.Changeset.fetch_argument(changeset, :base_image) do
      {:ok, base_image} ->
        device_id = Ash.Changeset.get_attribute(changeset, :device_id)
        ota = %{device_id: device_id, base_image_url: base_image.url}

        # TODO: this is not transactional, since if for some reason the database
        # operations fail, we would still have revert the OTA Operation that was
        # already sent to Astarte by create_managed_ota_operation!/2.
        # So we leave this like this for now and we'll revisit this when we add
        # support for canceling OTA Operations.
        Ash.Changeset.manage_relationship(changeset, :ota_operation, ota, on_no_match: {:create, :create_managed})

      :error ->
        Ash.Changeset.add_error(changeset, "base_image argument is required")
    end
  end
end
