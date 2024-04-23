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

defmodule Edgehog.Forwarder.Config.ManualActions.GetConfig do
  use Ash.Resource.ManualRead

  alias Edgehog.Forwarder.Config

  def read(_ash_query, _ecto_query, _opts, _context) do
    forwarder_config = Application.fetch_env!(:edgehog, :edgehog_forwarder)

    if forwarder_config.enabled? do
      {:ok,
       [
         %Config{
           hostname: forwarder_config.hostname,
           port: forwarder_config.port,
           secure_sessions: forwarder_config.secure_sessions?
         }
       ]}
    else
      {:ok, []}
    end
  end
end
