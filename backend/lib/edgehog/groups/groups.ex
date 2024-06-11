#
# This file is part of Edgehog.
#
# Copyright 2022-2024 SECO Mind Srl
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

defmodule Edgehog.Groups do
  @moduledoc """
  The Groups context.
  """

  use Ash.Domain, extensions: [AshGraphql.Domain]

  graphql do
    root_level_errors? true

    queries do
      get Edgehog.Groups.DeviceGroup, :device_group, :get
      list Edgehog.Groups.DeviceGroup, :device_groups, :list
    end

    mutations do
      create Edgehog.Groups.DeviceGroup, :create_device_group, :create
      update Edgehog.Groups.DeviceGroup, :update_device_group, :update
      destroy Edgehog.Groups.DeviceGroup, :delete_device_group, :destroy
    end
  end

  resources do
    resource Edgehog.Groups.DeviceGroup
  end
end
