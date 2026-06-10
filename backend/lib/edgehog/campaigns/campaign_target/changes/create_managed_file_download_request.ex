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

defmodule Edgehog.Campaigns.CampaignTarget.Changes.CreateManagedFileDownloadRequest do
  @moduledoc """
  An Ash change that creates a managed file download request for the target device.
  This change fetches the file and mechanism configuration from the arguments and creates
  a file download request associated with the target device.
  """

  use Ash.Resource.Change

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    case {Ash.Changeset.fetch_argument(changeset, :file),
          Ash.Changeset.fetch_argument(changeset, :mechanism)} do
      {{:ok, file}, {:ok, mechanism}} ->
        device_id = Ash.Changeset.get_attribute(changeset, :device_id)

        file_download_request_params = %{
          device_id: device_id,
          file_id: file.id,
          file_download_request_id: Ash.UUIDv7.generate(),
          compression: mechanism.compression,
          ttl_seconds: mechanism.ttl_seconds,
          file_mode: mechanism.file_mode,
          user_id: mechanism.user_id,
          group_id: mechanism.group_id,
          destination_type: mechanism.destination_type,
          destination: mechanism.destination,
          progress_tracked: true
        }

        Ash.Changeset.manage_relationship(
          changeset,
          :file_download_request,
          file_download_request_params,
          on_no_match: {:create, :managed}
        )

      {:error, _} ->
        Ash.Changeset.add_error(changeset, "file argument is required")

      {_, :error} ->
        Ash.Changeset.add_error(changeset, "mechanism argument is required")
    end
  end
end
