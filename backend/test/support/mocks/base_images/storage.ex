#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.Mocks.BaseImages.Storage do
  @behaviour Edgehog.BaseImages.Storage

  @bucket_url "https://sample-storage.com/bucket"

  alias Edgehog.BaseImages.BaseImage

  @impl true
  def store(%BaseImage{} = scope, %Plug.Upload{} = upload) do
    %BaseImage{
      tenant_id: tenant_id,
      base_image_collection_id: base_image_collection_id,
      version: version
    } = scope

    ext = Path.extname(upload.filename)

    file_name =
      "uploads/tenants/#{tenant_id}/base_image_collections/#{base_image_collection_id}/base_images/#{version}.#{ext}"

    file_url = "#{@bucket_url}/#{file_name}"
    {:ok, file_url}
  end

  @impl true
  def delete(%BaseImage{} = _scope) do
    :ok
  end
end
