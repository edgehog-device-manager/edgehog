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

defmodule Edgehog.Assets.SystemModelPicture do
  alias Edgehog.Devices.SystemModel
  alias Edgehog.Assets.Uploaders.SystemModelPicture

  @behaviour Edgehog.Assets.Store.Behaviour

  def upload(%SystemModel{} = scope, %Plug.Upload{} = upload) do
    with {:ok, file_name} <- SystemModelPicture.store({upload, scope}) do
      file_url = SystemModelPicture.url({file_name, scope})
      {:ok, file_url}
    end
  end

  def delete(%SystemModel{} = scope, url) do
    SystemModelPicture.delete({url, scope})
  end
end
