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

defmodule Edgehog.OSManagement.EphemeralImage do
  @moduledoc false
  @behaviour Edgehog.OSManagement.EphemeralImage.Behaviour

  alias Edgehog.OSManagement.Uploaders.EphemeralImage

  @impl Edgehog.OSManagement.EphemeralImage.Behaviour
  def upload(tenant_id, ota_operation_id, %Plug.Upload{} = upload) when is_binary(ota_operation_id) do
    scope = %{tenant_id: tenant_id, ota_operation_id: ota_operation_id}

    with {:ok, file_name} <- EphemeralImage.store({upload, scope}) do
      file_url = EphemeralImage.url({file_name, scope})
      {:ok, file_url}
    end
  end

  @impl Edgehog.OSManagement.EphemeralImage.Behaviour
  def delete(tenant_id, ota_operation_id, url) when is_binary(ota_operation_id) do
    scope = %{tenant_id: tenant_id, ota_operation_id: ota_operation_id}
    EphemeralImage.delete({url, scope})
  end
end
