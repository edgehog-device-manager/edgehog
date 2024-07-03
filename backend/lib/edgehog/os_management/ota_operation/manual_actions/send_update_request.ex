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

defmodule Edgehog.OSManagement.OTAOperation.ManualActions.SendUpdateRequest do
  use Ash.Resource.Actions.Implementation

  alias Edgehog.Astarte.Device.OTARequest
  alias Edgehog.Error.AstarteAPIError

  @ota_request_v1_module Application.compile_env(
                           :edgehog,
                           :astarte_ota_request_v1_module,
                           OTARequest.V1
                         )

  @impl true
  def run(input, _opts, _context) do
    %{
      id: ota_operation_id,
      base_image_url: base_image_url,
      device: %{
        device_id: device_id,
        appengine_client: client
      }
    } =
      Ash.load!(
        input.arguments.ota_operation,
        [:base_image_url, device: [:device_id, :appengine_client]],
        reuse_values?: true
      )

    with {:error, %Astarte.Client.APIError{} = api_error} <-
           @ota_request_v1_module.update(client, device_id, ota_operation_id, base_image_url) do
      reason =
        AstarteAPIError.exception(
          status: api_error.status,
          response: api_error.response
        )

      {:error, reason}
    end
  end
end
