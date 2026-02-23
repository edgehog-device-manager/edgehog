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

defmodule Edgehog.Files.FileDownloadRequest.Changes.HandleEphemeralFileDeletion do
  @moduledoc """
  Ash change responsible for deleting the ephemeral file associated
  with a file download request when the request is deleted.
  """

  use Ash.Resource.Change

  alias Edgehog.Files.EphemeralFile

  @ephemeral_file_module Application.compile_env(
                           :edgehog,
                           :files_ephemeral_file_module,
                           EphemeralFile
                         )

  @impl Ash.Resource.Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  def change(changeset, _opts, _context) do
    Ash.Changeset.after_transaction(changeset, &cleanup_file_url/2)
  end

  defp cleanup_file_url(changeset, {:ok, file_download_request} = result) do
    tenant_id = changeset.to_tenant

    # We do our best to clean up
    _ =
      @ephemeral_file_module.delete(
        tenant_id,
        file_download_request.id,
        file_download_request.url
      )

    result
  end

  defp cleanup_file_url(_changeset, result) do
    result
  end
end
