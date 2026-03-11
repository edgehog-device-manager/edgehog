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

defmodule Edgehog.Files.FileUploadRequest.Changes.SendFileUploadRequest do
  @moduledoc """
  Ash change responsible for sending a file upload request to the Astarte device
  after the file upload request resource has been created.
  """

  use Ash.Resource.Change

  alias Edgehog.Files

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, file_upload_request ->
      with :ok <- Files.send_file_upload_request(file_upload_request) do
        {:ok, file_upload_request}
      end
    end)
  end
end
