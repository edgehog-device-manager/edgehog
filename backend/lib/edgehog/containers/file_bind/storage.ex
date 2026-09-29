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

defmodule Edgehog.Containers.FileBind.Storage do
  @moduledoc """
  Storage helpers for target-less file binds.

  Objects live under `uploads/tenants/<tenant_id>/file_binds/<file_bind_id>/file`.
  The object key intentionally does not depend on the file name, since the
  name is only known when the upload is marked as uploaded, while the
  presigned upload URL is read before that.

  Objects are kept after the file download request completes so redeploys can
  reuse them. They are deleted when the file bind is destroyed.
  """

  @storage_module Application.compile_env(
                    :edgehog,
                    :presigned_urls_storage_module,
                    Edgehog.Storage
                  )

  def file_path(tenant_id, file_bind_id, _file_name \\ nil) do
    "uploads/tenants/#{tenant_id}/file_binds/#{file_bind_id}/file"
  end

  def create_presigned_urls(file_path) do
    @storage_module.create_presigned_urls(file_path)
  end

  def read_presigned_url(file_path) do
    @storage_module.read_presigned_url(file_path)
  end

  def delete(file_path) do
    @storage_module.delete(file_path)
  end
end
