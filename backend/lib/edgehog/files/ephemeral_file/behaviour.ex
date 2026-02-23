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

defmodule Edgehog.Files.EphemeralFile.Behaviour do
  @moduledoc """
  Behaviour for handling ephemeral files used in file download requests.
  """

  @type upload :: %Plug.Upload{}

  @callback upload(tenant_id :: String.t(), file_download_request_id :: String.t(), upload()) ::
              {:ok, file_url :: String.t()} | {:error, reason :: any}

  @callback delete(
              tenant_id :: String.t(),
              file_download_request_id :: String.t(),
              url :: String.t()
            ) ::
              :ok | {:error, reason :: any}
end
