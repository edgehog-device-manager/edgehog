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

defmodule Edgehog.UpdateCampaigns.UpdateTarget.Status do
  use Ash.Type.Enum,
    values: [
      idle: "The update campaign is waiting for the OTA Request to be sent.",
      in_progress: "The update target is in progress.",
      failed: "The update target has failed to be updated.",
      successful: "The update target was successfully updated."
    ]

  def graphql_type(_), do: :update_target_status
end
