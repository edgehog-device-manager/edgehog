#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Mocks.OSManagement.EphemeralImage do
  @behaviour Edgehog.OSManagement.EphemeralImage.Behaviour

  @bucket_url "https://sample-storage.com/bucket"

  @impl true
  def upload(tenant_id, ota_operation_id, %Plug.Upload{} = upload) do
    file_name =
      "uploads/tenants/#{tenant_id}/ephemeral_ota_images/#{ota_operation_id}/#{upload.filename}"

    file_url = "#{@bucket_url}/#{file_name}"
    {:ok, file_url}
  end

  @impl true
  def delete(_tenant_id, _ota_operation_id, _url) do
    :ok
  end
end
