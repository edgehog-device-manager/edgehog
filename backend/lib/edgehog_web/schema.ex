#
# This file is part of Edgehog.
#
# Copyright 2021 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema do
  @moduledoc false
  use Absinthe.Schema

  use AshGraphql,
    domains: [
      Edgehog.BaseImages,
      Edgehog.Containers,
      Edgehog.Devices,
      Edgehog.Forwarder,
      Edgehog.Groups,
      Edgehog.Labeling,
      Edgehog.OSManagement,
      Edgehog.Tenants,
      Edgehog.Campaigns
    ],
    relay_ids?: true

  import_types EdgehogWeb.Schema.AstarteTypes
  import_types Absinthe.Plug.Types
  import_types Absinthe.Type.Custom

  query do
  end

  mutation do
  end

  subscription do
  end
end
