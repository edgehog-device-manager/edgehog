#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Mocks.Assets.SystemModelPicture do
  alias Edgehog.Devices.SystemModel
  alias Edgehog.Repo

  @behaviour Edgehog.Assets.Store.Behaviour

  @bucket_url "https://sample-storage.com/bucket"

  @impl true
  def upload(%SystemModel{} = system_model, %Plug.Upload{} = upload) do
    tenant_id = Repo.get_tenant_id()

    file_name =
      "tenants/#{tenant_id}/system_models/#{system_model.handle}/picture/#{upload.filename}"

    file_url = "#{@bucket_url}/#{file_name}"
    {:ok, file_url}
  end

  @impl true
  def delete(%SystemModel{} = _system_model, _picture_url) do
    :ok
  end
end
