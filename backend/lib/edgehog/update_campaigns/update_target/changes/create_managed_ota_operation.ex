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

defmodule Edgehog.UpdateCampaigns.UpdateTarget.Changes.CreateManagedOTAOperation do
  use Ash.Resource.Change

  alias Edgehog.OSManagement

  @impl Ash.Resource.Change
  def change(changeset, _opts, context) do
    %{tenant: tenant} = context

    {:ok, base_image} = Ash.Changeset.fetch_argument(changeset, :base_image)

    device_id = Ash.Changeset.get_attribute(changeset, :device_id)

    Ash.Changeset.before_action(changeset, fn changeset ->
      # TODO: this is not transactional, since if for some reason the database
      # operations fail, we would still have revert the OTA Operation that was
      # already sent to Astarte by create_managed_ota_operation!/2.
      # So we leave this like this for now and we'll revisit this when we add
      # support for canceling OTA Operations.
      ota_operation =
        OSManagement.create_managed_ota_operation!(
          %{device_id: device_id, base_image_url: base_image.url},
          tenant: tenant
        )

      Ash.Changeset.change_attribute(changeset, :ota_operation_id, ota_operation.id)
    end)
  end
end
