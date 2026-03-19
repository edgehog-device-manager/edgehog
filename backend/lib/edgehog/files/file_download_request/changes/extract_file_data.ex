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

defmodule Edgehog.Files.FileDownloadRequest.Changes.ExtractFileData do
  @moduledoc false

  use Ash.Resource.Change

  alias Edgehog.Files

  @impl Ash.Resource.Change
  def change(changeset, _opts, %{tenant: tenant} = _context) do
    file_id = Ash.Changeset.get_argument(changeset, :file_id)
    file = Files.File |> Ash.get!(file_id, tenant: tenant) |> Ash.load!(:get_presigned_url)

    changeset
    |> Ash.Changeset.change_attribute(:file_name, file.name)
    |> Ash.Changeset.change_attribute(:uncompressed_file_size_bytes, file.size)
    |> Ash.Changeset.change_attribute(:digest, file.digest)
    |> Ash.Changeset.change_attribute(:url, file.get_presigned_url)
  end
end
