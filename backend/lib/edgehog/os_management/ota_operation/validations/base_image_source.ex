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

defmodule Edgehog.OSManagement.OTAOperation.Validations.BaseImageSource do
  @moduledoc false

  use Ash.Resource.Validation

  alias Ash.Changeset

  @impl Ash.Resource.Validation
  def validate(changeset, _opts, _context) do
    file = Changeset.get_argument(changeset, :base_image_file)
    url = Changeset.get_argument(changeset, :base_image_url)

    case {file, url} do
      {nil, nil} ->
        {:error, fields: [:base_image_file, :base_image_url], message: "no image file nor url"}

      {_file, nil} ->
        :ok

      {nil, _url} ->
        :ok

      {_, _} ->
        {:error, fields: [:base_image_file, :base_image_url], message: "only one between image file or url is supported"}
    end
  end
end
