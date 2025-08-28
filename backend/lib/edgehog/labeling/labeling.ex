#
# This file is part of Edgehog.
#
# Copyright 2022 - 2025 SECO Mind Srl
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

defmodule Edgehog.Labeling do
  @moduledoc """
  The Labeling context, containing all functionalities regarding tags and attributes assignment
  """

  use Ash.Domain, extensions: [AshGraphql.Domain]

  alias Edgehog.Labeling.Tag

  graphql do
    root_level_errors? true

    queries do
      list Tag, :existing_device_tags, :read_assigned_to_devices do
        description "Returns the list of device tags associated to some device group."
        relay? true
        paginate_with :keyset
      end
    end
  end

  resources do
    resource Edgehog.Labeling.DeviceTag
    resource Tag
  end
end
