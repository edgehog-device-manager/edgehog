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

defmodule Edgehog.TelemetryCapture do
  @moduledoc """
  Helper to attach and assert telemetry events in tests.
  """

  import ExUnit.Assertions
  import ExUnit.Callbacks

  @doc """
  Attaches a handler that forwards the events in `events` to the current
  process as `{:telemetry_event, event, measurements, metadata}` messages.
  """
  def start_capture(events) do
    parent = self()

    handler_ids =
      for event <- events do
        handler_id = {__MODULE__, event, make_ref()}

        :telemetry.attach(
          handler_id,
          event,
          fn event, measurements, metadata, _config ->
            send(parent, {:telemetry_event, event, measurements, metadata})
          end,
          nil
        )

        handler_id
      end

    on_exit(fn -> Enum.each(handler_ids, &:telemetry.detach/1) end)
  end

  @doc """
  Asserts that an event with the given name was received, returning the
  measurements and metadata of the received event.
  """
  def assert_receive_event(event, timeout \\ 1000) do
    assert_receive {:telemetry_event, ^event, measurements, metadata}, timeout
    {measurements, metadata}
  end
end
