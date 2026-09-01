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

defmodule Edgehog.Containers.Validations.ContainsFile do
  @moduledoc """
  Edgehog validation on FileBind input types.

  Checks that a file bind (or a list of file binds) actually contains a valid
  file reference. Either:
  - a file url
  - a file download request id
  - a device file id
  """

  use Ash.Resource.Validation

  @impl Ash.Resource.Validation
  def init(opts) do
    case Keyword.fetch(opts, :arg) do
      {:ok, _field} -> {:ok, opts}
      :error -> {:error, "Requires a changeset input argument to check."}
    end
  end

  @impl Ash.Resource.Validation
  def validate(changeset, opts, _context) do
    value = Ash.Changeset.get_argument(changeset, opts[:arg])

    if is_list(value),
      do: check_every(value, opts),
      else: check(value, opts)
  end

  defp check_every(binds, opts) do
    Enum.reduce_while(binds, :ok, fn bind, :ok ->
      case check(bind, opts) do
        {:error, message: message} -> {:halt, {:error, field: :file_bind, message: message}}
        _ -> {:cont, :ok}
      end
    end)
  end

  defp check(bind, _opts) do
    device_file_id = Map.fetch(bind, :device_file_id)
    file_download_request_id = Map.fetch(bind, :file_download_request_id)
    file_url = Map.fetch(bind, :file_url)

    with {:error, :error, :error} <- {device_file_id, file_download_request_id, file_url} do
      {:error,
       message:
         "File binds require at least one between a device file id, a file download request id or a file url to be defined."}
    end
  end
end
