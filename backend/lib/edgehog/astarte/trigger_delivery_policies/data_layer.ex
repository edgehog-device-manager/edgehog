#
# This file is part of Edgehog.
#
# Copyright 2023 - 2025 SECO Mind Srl
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

defmodule Edgehog.Astarte.DeliveryPolicies.DataLayer do
  @moduledoc false
  alias Astarte.Client.RealmManagement

  @callback get(client :: RealmManagement.t(), policy_name :: String.t()) ::
              {:ok, map()} | {:error, term()}

  @callback create(client :: RealmManagement.t(), policy_json :: map()) ::
              :ok | {:error, term()}

  @callback delete(client :: RealmManagement.t(), policy_name :: String.t()) ::
              :ok | {:error, term()}
end
