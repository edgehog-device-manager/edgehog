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

defmodule Edgehog.Files.FileDeleteRequest.Status do
  @moduledoc """
  Status of a file delete request.

  Lifecycle:
    pending -> sent -> completed
                 \-> failed

  """
  use Ash.Type.Enum,
    values: [
      pending: "Request created in database, not yet sent to device",
      sent: "Request sent to device via Astarte, awaiting response",
      completed: "Deletion completed successfully (response_code = 0)",
      failed: "Deletion failed (response_code != 0 or timeout)"
    ]

  def graphql_type(_), do: :file_delete_request_status
end
