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

defmodule Edgehog.Devices.Device.ManualActions.SendCreateImageRequest do
  @moduledoc false
  use Ash.Resource.ManualUpdate

  require Ash.Query

  @send_create_image_request_behaviour Application.compile_env(
                                         :edgehog,
                                         :astarte_create_image_request_module,
                                         Edgehog.Astarte.Device.CreateImageRequest
                                       )

  @impl Ash.Resource.ManualUpdate
  def update(changeset, _opts, _context) do
    device = changeset.data

    image = changeset.arguments.image
    credentials = changeset.arguments.credentials

    data = %{
      image_id: image.id,
      reference: image.reference,
      credentials: credentials.base64_json
    }

    with {:ok, device} <- Ash.load(device, :appengine_client) do
      @send_create_image_request_behaviour.send_create_image_request(
        device.appengine_client,
        device.device_id,
        data
      )
    end
  end
end
