#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Edgehog.OSManagement.OTAOperation.Changes.LogOtaOperationOutcome do
  @moduledoc false
  use Ash.Resource.Change

  require Logger

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, &log_ota_operation_outcome/2)
  end

  defp log_ota_operation_outcome(changeset, {:ok, ota_operation} = result) do
    tenant_id = changeset.to_tenant

    case ota_operation.status do
      :success ->
        Logger.info(
          "OTA operation #{ota_operation.id} on device #{ota_operation.device_id} completed successfully with status code #{ota_operation.status_code} and message: #{ota_operation.message}",
          tenant_id: tenant_id
        )

      :failure ->
        Logger.info(
          "OTA operation #{ota_operation.id} on device #{ota_operation.device_id} failed with status code #{ota_operation.status_code} and message: #{ota_operation.message}",
          tenant_id: tenant_id
        )

      _ ->
        :ok
    end

    result
  end

  defp log_ota_operation_outcome(_changeset, result) do
    result
  end
end
