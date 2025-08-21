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

defmodule Edgehog.Error.AstarteAPIError do
  @moduledoc "Used when Astarte replies with an APIError"
  use Splode.Error, fields: [:status, :response, :device_id, :interface], class: :invalid

  # TODO: this should probably be split in at least 2 different errors: one for
  # 403/401 responses, with class :forbidden, and another one from generic
  # API Errors

  def message(error) do
    # If we already have a single error message we show that, otherwise we
    # encode the whole response
    error_details =
      case error.response do
        %{"error" => %{"detail" => error_message}} -> error_message
        %{"errors" => %{"detail" => error_message}} -> error_message
        response -> Jason.encode!(response)
      end

    # TODO: change old usages of `AstarteAPIError` to include device_id and
    # interface
    device_id = Map.get(error, :device_id, "Unknown")
    interface = Map.get(error, :interface, "Unknown")

    """
    Astarte API Error with status #{error.status}:

    #{error_details}

    on device #{device_id} and interface #{interface}
    """
  end

  defimpl AshGraphql.Error do
    def to_error(error) do
      %{
        message: Exception.message(error),
        short_message: "Astarte API Error (status #{error.status})",
        vars: %{},
        code: "astarte_api_error",
        fields: []
      }
    end
  end
end
