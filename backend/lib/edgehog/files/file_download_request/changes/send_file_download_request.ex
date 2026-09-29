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

defmodule Edgehog.Files.FileDownloadRequest.Changes.SendFileDownloadRequest do
  @moduledoc """
  Ash change responsible for sending a file download request to the Astarte device
  after the file download request resource has been created.
  """

  use Ash.Resource.Change

  alias Edgehog.Files.FileDownloadRequest.Provisioner

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant}) do
    Ash.Changeset.after_transaction(changeset, fn _changeset, result ->
      with {:ok, file_download_request} <- result,
           {:ok, _pid} <- Provisioner.provision(file_download_request, tenant) do
        {:ok, file_download_request}
      end
    end)
  end
end
