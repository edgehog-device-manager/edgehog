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

defmodule Edgehog.Error do
  @moduledoc """
  Error utilites to match device errors when communicating with astarte.
  """

  alias Astarte.Client.APIError
  alias Edgehog.Error

  @doc """
  Translates `Astarte.Client.APIError`s into `Edgehog.Error`s, letting `:ok` | `{:ok, value}` be themselves.

  ## Example

  Error.maybe_match_error(:ok, device_id, interface) => :ok
  Error.maybe_match_error({:ok, value}, device_id, interface) => {:ok, value}

  Error.maybe_match_error({:error, reason}, device_id, interface) => {:error, converted_reason}
  """
  def maybe_match_error({:error, %APIError{status: 404}}, device_id, interface) do
    error =
      Error.DeviceOffline.exception(
        device_id: device_id,
        interface: interface
      )

    {:error, error}
  end

  def maybe_match_error({:error, %APIError{status: status, response: response}}, device_id, interface) do
    error =
      Error.AstarteAPIError.exception(
        status: status,
        response: response,
        device_id: device_id,
        interface: interface
      )

    {:error, error}
  end

  def maybe_match_error(ok, _, _), do: ok
end
