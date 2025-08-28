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

  alias Edgehog.Groups.DeviceGroup

  graphql do
    root_level_errors? true

    queries do
      get DeviceGroup, :device_group, :read do
        description "Returns a single device group."
      end

      list DeviceGroup, :device_groups, :read do
        description "Returns a list of device groups."
        paginate_with :keyset
        relay? true
      end
    end

    mutations do
      create DeviceGroup, :create_device_group, :create
      update DeviceGroup, :update_device_group, :update
      destroy DeviceGroup, :delete_device_group, :destroy
    end
  end

  resources do
    resource DeviceGroup
  end
end
