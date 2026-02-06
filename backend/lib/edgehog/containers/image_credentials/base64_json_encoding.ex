#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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

defmodule Edgehog.Containers.ImageCredentials.Base64JsonEncoding do
  @moduledoc false
  use Ash.Resource.Calculation

  alias Ash.Resource.Calculation
  alias AshGraphql.Types.JSONString

  @impl Calculation
  def load(_query, _opts, _context), do: [:username, :password]

  @impl Calculation
  def calculate(records, _opts, _context) do
    for record <- records do
      auth =
        %{
          username: record.username,
          password: record.password
        }

      auth =
        case record.serveraddress do
          nil -> auth
          server_address -> Map.put(auth, :serveraddress, server_address)
        end

      auth
      |> JSONString.encode()
      |> Base.encode64()
    end
  end
end
