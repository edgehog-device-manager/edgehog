#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Edgehog.Forwarder.Telemetry do
  @moduledoc """
  Emits the telemetry events of the forwarder feature.

  Events can be emitted on the following topics:

  - `[:edgehog, :forwarder, :session, :requested]` when a new forwarder session
    is requested to a device. Metadata contains `tenant_slug`.
  """

  @session_requested [:edgehog, :forwarder, :session, :requested]

  def session_requested_event, do: @session_requested

  def session_requested(tenant) do
    :telemetry.execute(@session_requested, %{count: 1}, %{tenant_slug: tenant.slug})
  end
end
