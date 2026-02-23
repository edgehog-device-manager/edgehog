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

defmodule Edgehog.Files.EphemeralFile do
  @moduledoc """
  Module responsible for handling ephemeral files used in file download requests.
  """

  @behaviour Edgehog.Files.EphemeralFile.Behaviour

  alias Edgehog.Files.Uploaders.EphemeralFile

  @impl Edgehog.Files.EphemeralFile.Behaviour
  def upload(tenant_id, file_download_request_id, %Plug.Upload{} = upload) when is_binary(file_download_request_id) do
    scope = %{tenant_id: tenant_id, file_download_request_id: file_download_request_id}

    with {:ok, file_name} <- EphemeralFile.store({upload, scope}) do
      file_url = EphemeralFile.url({file_name, scope})
      {:ok, file_url}
    end
  end

  @impl Edgehog.Files.EphemeralFile.Behaviour
  def delete(tenant_id, file_download_request_id, url) when is_binary(file_download_request_id) do
    scope = %{tenant_id: tenant_id, file_download_request_id: file_download_request_id}
    EphemeralFile.delete({url, scope})
  end
end
