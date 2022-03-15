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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Assets do
  alias Edgehog.Assets.SystemModelPicture

  @assets_system_model_picture_module Application.compile_env(
                                        :edgehog,
                                        :assets_system_model_picture_module,
                                        SystemModelPicture
                                      )

  def upload_system_model_picture(_system_model, nil) do
    {:ok, nil}
  end

  def upload_system_model_picture(system_model, picture_file) do
    with :ok <- ensure_storage_enabled() do
      @assets_system_model_picture_module.upload(system_model, picture_file)
    end
  end

  def delete_system_model_picture(_system_model, nil) do
    :ok
  end

  def delete_system_model_picture(system_model, picture_url) do
    with :ok <- ensure_storage_enabled() do
      @assets_system_model_picture_module.delete(system_model, picture_url)
    end
  end

  defp ensure_storage_enabled do
    if Application.get_env(:edgehog, :enable_s3_storage?, false) do
      :ok
    else
      {:error, :storage_disabled}
    end
  end
end
