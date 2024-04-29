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

defmodule Edgehog.OSManagement.OTAOperation.Status do
  use Ash.Type.Enum,
    values: [
      pending: "The OTA operation was created and is waiting an acknowledgment from the device",
      acknowledged: "The OTA operation was acknowledged from the device",
      downloading: "The device is downloading the update",
      deploying: "The device is deploying the update",
      deployed: "The device deployed the update",
      rebooting: "The device is in the process of rebooting",
      error: "A recoverable error happened during the OTA operation",
      failure:
        "The OTA operation ended with a failure. This is a final state of the OTA Operation",
      success: "The OTA operation ended successfully. This is a final state of the OTA Operation"
    ]

  def graphql_type(_), do: :ota_operation_status
end
