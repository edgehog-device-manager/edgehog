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

defmodule Edgehog.Triggers.Event do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        device_registered: [
          type: Edgehog.Triggers.DeviceRegistered,
          tag: :type,
          tag_value: "device_registered",
          cast_tag?: false
        ],
        device_connected: [
          type: Edgehog.Triggers.DeviceConnected,
          tag: :type,
          tag_value: "device_connected",
          cast_tag?: false
        ],
        device_disconnected: [
          type: Edgehog.Triggers.DeviceDisconnected,
          tag: :type,
          tag_value: "device_disconnected",
          cast_tag?: false
        ],
        device_deleted: [
          type: Edgehog.Triggers.DeviceDeletionFinished,
          tag: :type,
          tag_value: "device_deletion_finished",
          cast_tag?: false
        ],
        incoming_data: [
          type: Edgehog.Triggers.IncomingData,
          tag: :type,
          tag_value: "incoming_data",
          cast_tag?: false
        ]
      ]
    ]
end
