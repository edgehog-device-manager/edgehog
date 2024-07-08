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

defmodule Edgehog.BaseImages.BucketStorage do
  @moduledoc false
  @behaviour Edgehog.BaseImages.Storage

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.BaseImages.Storage
  alias Edgehog.BaseImages.Uploaders

  @impl Storage
  def store(%BaseImage{} = scope, %Plug.Upload{} = upload) do
    with {:ok, file_name} <- Uploaders.BaseImage.store({upload, scope}) do
      # TODO: investigate URL signing instead of public access
      file_url = Uploaders.BaseImage.url({file_name, scope})
      {:ok, file_url}
    end
  end

  @impl Storage
  def delete(%BaseImage{} = scope) do
    %BaseImage{url: url} = scope
    Uploaders.BaseImage.delete({url, scope})
  end
end
