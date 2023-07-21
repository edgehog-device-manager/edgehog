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

defmodule Edgehog.BaseImages.Uploaders.BaseImage do
  use Waffle.Definition

  @async false
  @acl :public_read
  @versions [:original]

  def validate(_) do
    # TODO: everything is considered a valid base image for now
    true
  end

  def gcs_optional_params(_version, {_file, _scope}) do
    [predefinedAcl: "publicRead"]
  end

  def storage_dir(_version, {_file, scope}) do
    %{
      tenant_id: tenant_id,
      base_image_collection_id: base_image_collection_id
    } = scope

    "uploads/tenants/#{tenant_id}/base_image_collections/#{base_image_collection_id}/base_images"
  end

  def filename(_version, {_file, scope}) do
    scope.version
  end
end
