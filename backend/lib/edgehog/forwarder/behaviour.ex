#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.Forwarder.Behaviour do
  alias Edgehog.Astarte.Device.ForwarderSession
  alias Edgehog.Devices.Device

  @callback forwarder_enabled?() :: boolean()

  @callback fetch_forwarder_session(device :: %Device{}, session_token :: String.t()) ::
              {:ok, ForwarderSession.t()} | {:error, term()}

  @callback fetch_or_request_available_forwarder_session_token(device :: %Device{}) ::
              {:ok, session_token :: String.t()} | {:error, term()}
end
