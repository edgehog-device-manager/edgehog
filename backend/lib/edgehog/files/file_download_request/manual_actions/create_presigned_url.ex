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

defmodule Edgehog.Files.FileDownloadRequest.ManualActions.CreatePresignedUrl do
  @moduledoc """
  The Storage context.
  """
  use Ash.Resource.Actions.Implementation

  @impl Ash.Resource.Actions.Implementation
  def run(input, _opts, context) do
    tenant_id = context.tenant.tenant_id
    file_download_request_id = input.arguments.file_download_request_id
    filename = input.arguments.filename

    file_path =
      "uploads/tenants/#{tenant_id}/ephemeral_file_download_requests/#{file_download_request_id}/files/#{filename}"

    Edgehog.Storage.create_presigned_urls(file_path)
  end
end
