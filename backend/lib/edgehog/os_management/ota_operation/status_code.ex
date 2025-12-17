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

defmodule Edgehog.OSManagement.OTAOperation.StatusCode do
  @moduledoc false
  use Ash.Type.Enum,
    values: [
      request_timeout: "The OTA Operation timed out while sending the request to the device",
      invalid_request: "The OTA Operation contained invalid data",
      update_already_in_progress: "An OTA Operation is already in progress on the device",
      network_error: "A network error was encountered",
      io_error: "An IO error was encountered",
      internal_error: "An internal error was encountered",
      invalid_base_image: "The OTA Operation failed due to an invalid base image",
      system_rollback: "A system rollback has occurred",
      canceled: "The OTA Operation was canceled"
    ]

  def graphql_type(_), do: :ota_operation_status_code

  # Ash.Type.Enum expects snake case input and lowercases everything
  # This works even with PascalCase inputs if they are a single word, but we
  # need to match explicitly multiword status codes
  def match("RequestTimeout"), do: {:ok, :request_timeout}
  def match("InvalidRequest"), do: {:ok, :invalid_request}
  def match("UpdateAlreadyInProgress"), do: {:ok, :update_already_in_progress}
  def match("NetworkError"), do: {:ok, :network_error}
  def match("IOError"), do: {:ok, :io_error}
  def match("InternalError"), do: {:ok, :internal_error}
  def match("InvalidBaseImage"), do: {:ok, :invalid_base_image}
  def match("SystemRollback"), do: {:ok, :system_rollback}
  # Fallback to the default (overridden) `match/1` implementation so we still accept
  # atom inputs etc
  def match(term), do: super(term)
end
