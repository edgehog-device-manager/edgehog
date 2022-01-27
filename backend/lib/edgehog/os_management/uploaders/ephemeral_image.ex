#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.OSManagement.Uploaders.EphemeralImage do
  use Waffle.Definition

  @acl :public_read
  @versions [:original]

  def validate(_) do
    # TODO: everything is considered a valid OTA image for now
    true
  end

  def gcs_optional_params(_version, {_file, _scope}) do
    [predefinedAcl: "publicRead"]
  end

  def storage_dir(_version, {_file, %{tenant_id: tenant_id, ota_operation_id: ota_operation_id}}) do
    "uploads/tenants/#{tenant_id}/ephemeral_ota_images/#{ota_operation_id}"
  end
end
