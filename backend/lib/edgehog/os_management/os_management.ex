#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule Edgehog.OSManagement do
  use Ash.Domain,
    extensions: [
      AshGraphql.Domain
    ]

  graphql do
    root_level_errors? true
  end

  resources do
    resource Edgehog.OSManagement.OTAOperation do
      define :fetch_ota_operation, action: :read, get_by: [:id], not_found_error?: true
      define :create_managed_ota_operation, action: :create_managed
      define :mark_ota_operation_as_timed_out, action: :mark_as_timed_out
      define :update_ota_operation_status, action: :update_status, args: [:status]
      define :send_update_request, args: [:ota_operation]
    end
  end
end
