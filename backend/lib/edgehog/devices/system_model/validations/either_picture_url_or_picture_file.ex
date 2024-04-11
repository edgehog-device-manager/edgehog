#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Devices.SystemModel.Validations.EitherPictureUrlOrPictureFile do
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    with {:ok, url} when is_binary(url) <-
           Ash.Changeset.fetch_argument_or_change(changeset, :picture_url),
         {:ok, %Plug.Upload{} = _upload} <-
           Ash.Changeset.fetch_argument_or_change(changeset, :picture_file) do
      {:error, field: :picture_url, message: "is mutually exclusive with picture_file"}
    else
      _ ->
        :ok
    end
  end
end
