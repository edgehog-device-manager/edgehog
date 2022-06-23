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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Edgehog.Devices.DeviceTag do
  use Ecto.Schema
  import Ecto.Query
  alias Edgehog.Devices.DeviceTag
  alias Edgehog.Devices.Tag

  @primary_key false
  schema "devices_tags" do
    field :tenant_id, :integer, autogenerate: {Edgehog.Repo, :get_tenant_id, []}
    field :tag_id, :id, primary_key: true
    field :device_id, :id, primary_key: true
  end

  def device_ids_matching_tag(tag) when is_binary(tag) do
    from dt in DeviceTag,
      join: t in Tag,
      on: dt.tag_id == t.id,
      where: t.name == ^tag,
      select: dt.device_id
  end
end
