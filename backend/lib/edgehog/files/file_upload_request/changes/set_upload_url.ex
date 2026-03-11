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

defmodule Edgehog.Files.FileUploadRequest.Changes.SetUploadUrl do
  @moduledoc """
  Ash change responsible for generating and setting a presigned upload URL
  for a file upload request before persisting it.
  """

  use Ash.Resource.Change

  alias Ash.Resource.Change

  @files_storage_module Application.compile_env(
                          :edgehog,
                          :files_storage_module,
                          Edgehog.Storage
                        )

  @impl Change
  def change(%Ash.Changeset{valid?: false} = changeset, _opts, _context), do: changeset

  @impl Change
  def change(changeset, _opts, context) do
    tenant_id = context.tenant.tenant_id
    file_upload_request_id = Ash.Changeset.get_attribute(changeset, :id)

    file_path =
      "uploads/tenants/#{tenant_id}/file_upload_requests/#{file_upload_request_id}"

    case @files_storage_module.create_presigned_urls(file_path) do
      {:ok, %{put_url: put_url}} -> Ash.Changeset.change_attribute(changeset, :url, put_url)
      {:error, reason} -> Ash.Changeset.add_error(changeset, reason)
    end
  end
end
