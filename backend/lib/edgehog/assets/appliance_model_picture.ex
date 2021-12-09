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

defmodule Edgehog.Assets.ApplianceModelPicture do
  alias Edgehog.Appliances.ApplianceModel
  alias Edgehog.Assets.Uploaders.ApplianceModelPicture

  @behaviour Edgehog.Assets.Store.Behaviour

  def upload(%ApplianceModel{} = scope, %Plug.Upload{} = upload) do
    with {:ok, file_name} <- ApplianceModelPicture.store({upload, scope}) do
      file_url = ApplianceModelPicture.url({file_name, scope})
      {:ok, file_url}
    end
  end

  def delete(%ApplianceModel{} = scope, url) do
    ApplianceModelPicture.delete({url, scope})
  end
end
