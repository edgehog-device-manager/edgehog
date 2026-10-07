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

defmodule Edgehog.Files.Telemetry do
  @moduledoc """
  Edgehog file transfer telemetry.

  Events can be emitted on the following topics:

  - `[:edgehog, :files, :file_download_request, :start]` when a file download
    request provisioning starts. Metadata contains `transfer_type`, `destination_type`,
    `progress_tracked`, `needs_encoding`, `tenant_slug`, and optionally `request_id`, `device_id`,
    and `file_id`.
  - `[:edgehog, :files, :file_download_request, :stop]` when a file download
    request terminates, either successfully or with a failure. Metadata contains
    the start metadata plus `result` (either `:ok` or `:error`), `reason` (either
    the provisioning outcome, e.g. `:ready` or `:already_ready`, or the failure reason),
    `duration` (native time), and `duration_unit` (`:native`). Measurements contain
    `count`, `duration` (native time), and `retries`.
  - `[:edgehog, :files, :file_upload_request, :start]` when a file upload
    request starts. Metadata contains `transfer_type`, `source_type`,
    `progress_tracked`, `needs_encoding`, `tenant_slug`, and optionally `request_id` and `device_id`.
  - `[:edgehog, :files, :file_upload_request, :stop]` when a file upload
    request terminates, either successfully or with a failure. Metadata contains
    the start metadata plus `result` (either `:ok` or `:error`), `reason`,
    `duration` (native time), and `duration_unit` (`:native`). Measurements contain
    `count`, `duration` (native time), and `retries`.
  """

  alias Edgehog.Config

  @file_download_request_start [:edgehog, :files, :file_download_request, :start]
  @file_download_request_stop [:edgehog, :files, :file_download_request, :stop]
  @file_upload_request_start [:edgehog, :files, :file_upload_request, :start]
  @file_upload_request_stop [:edgehog, :files, :file_upload_request, :stop]

  def file_download_start_event, do: @file_download_request_start
  def file_download_stop_event, do: @file_download_request_stop
  def file_upload_start_event, do: @file_upload_request_start
  def file_upload_stop_event, do: @file_upload_request_stop

  @doc """
  Emits a file download request start event and returns the monotonic time the
  download request started, to be used when emitting the corresponding stop event.

  Returns the start time, computed with `System.monotonic_time/0`.
  """
  def file_download_request_started(resource, context) do
    start = System.monotonic_time()

    metadata =
      [started_at: start]
      |> Keyword.merge(base_download_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(
      @file_download_request_start,
      %{count: 1, system_time: System.system_time()},
      metadata
    )

    start
  end

  @doc """
  Emits a successful file download request stop event.
  """
  def file_download_request_completed(
        resource,
        context,
        started_at,
        retries \\ 0,
        reason \\ :ready
      ) do
    duration = duration_since(started_at)

    metadata =
      [
        result: :ok,
        reason: reason,
        duration: duration,
        duration_unit: :native
      ]
      |> Keyword.merge(base_download_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(
      @file_download_request_stop,
      %{count: 1, duration: duration, retries: retries},
      metadata
    )
  end

  @doc """
  Emits a failed file download request stop event.
  """
  def file_download_request_failed(resource, context, started_at, retries \\ 0, reason) do
    duration = duration_since(started_at)

    metadata =
      [
        result: :error,
        reason: reason,
        duration: duration,
        duration_unit: :native
      ]
      |> Keyword.merge(base_download_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(
      @file_download_request_stop,
      %{count: 1, duration: duration, retries: retries},
      metadata
    )
  end

  @doc """
  Emits a file upload request start event and returns the monotonic time the
  upload request started, to be used when emitting the corresponding stop event.

  Returns the start time, computed with `System.monotonic_time/0`.
  """
  def file_upload_request_started(resource, context) do
    start = System.monotonic_time()

    metadata =
      [started_at: start]
      |> Keyword.merge(base_upload_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(
      @file_upload_request_start,
      %{count: 1, system_time: System.system_time()},
      metadata
    )

    start
  end

  @doc """
  Emits a successful file upload request stop event.
  """
  def file_upload_request_completed(
        resource,
        context,
        started_at,
        retries \\ 0,
        reason \\ :ok
      ) do
    duration = duration_since(started_at)

    metadata =
      [
        result: :ok,
        reason: reason,
        duration: duration,
        duration_unit: :native
      ]
      |> Keyword.merge(base_upload_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(
      @file_upload_request_stop,
      %{count: 1, duration: duration, retries: retries},
      metadata
    )
  end

  @doc """
  Emits a failed file upload request stop event.
  """
  def file_upload_request_failed(resource, context, started_at, retries \\ 0, reason) do
    duration = duration_since(started_at)

    metadata =
      [
        result: :error,
        reason: reason,
        duration: duration,
        duration_unit: :native
      ]
      |> Keyword.merge(base_upload_metadata(resource, context))
      |> Map.new()

    :telemetry.execute(
      @file_upload_request_stop,
      %{count: 1, duration: duration, retries: retries},
      metadata
    )
  end

  @doc """
  Returns true if telemetry identifiers should be included in event metadata.
  """
  def include_identifiers?, do: Config.files_telemetry_include_identifiers!()

  defp base_download_metadata(resource, context) do
    destination_type = get_value(resource, :destination_type)
    progress_tracked = get_value(resource, :progress_tracked, false) == true
    needs_encoding = needs_encoding?(resource)

    [
      transfer_type: :download,
      destination_type: destination_type,
      progress_tracked: progress_tracked,
      needs_encoding: needs_encoding
    ] ++
      download_identifiers_metadata(resource, context) ++
      tenant_metadata(context)
  end

  defp base_upload_metadata(resource, context) do
    source_type = get_value(resource, :source_type)
    progress_tracked = get_value(resource, :progress_tracked, false) == true
    needs_encoding = needs_encoding?(resource)

    [
      transfer_type: :upload,
      source_type: source_type,
      progress_tracked: progress_tracked,
      needs_encoding: needs_encoding
    ] ++
      upload_identifiers_metadata(resource, context) ++
      tenant_metadata(context)
  end

  defp tenant_metadata(context) do
    context
    |> Keyword.fetch!(:tenant)
    |> then(&[tenant: &1.slug])
  end

  defp download_identifiers_metadata(resource, context) do
    if include_identifiers?() do
      device_id =
        get_value(resource, :device_id) ||
          nested_value(resource, [:device, :id]) ||
          get_value(context, :device_id)

      file_id =
        get_value(resource, :file_id) ||
          nested_value(resource, [:device_file, :file_id]) ||
          get_value(context, :file_id)

      [
        request_id: get_value(resource, :id),
        device_id: device_id,
        file_id: file_id
      ]
    else
      []
    end
  end

  defp upload_identifiers_metadata(resource, context) do
    if include_identifiers?() do
      device_id =
        get_value(resource, :device_id) ||
          nested_value(resource, [:device, :id]) ||
          get_value(context, :device_id)

      [
        request_id: get_value(resource, :id),
        device_id: device_id
      ]
    else
      []
    end
  end

  defp needs_encoding?(resource) do
    case get_value(resource, :encoding) do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  defp get_value(map, key, default \\ nil)
  defp get_value(map, key, default) when is_map(map), do: Map.get(map, key, default)
  defp get_value(list, key, default) when is_list(list), do: Keyword.get(list, key, default)
  defp get_value(_other, _key, default), do: default

  defp nested_value(map, [key]) when is_map(map), do: Map.get(map, key)
  defp nested_value(list, [key]) when is_list(list), do: Keyword.get(list, key)

  defp nested_value(container, [key | rest]) when is_map(container) or is_list(container) do
    case get_value(container, key) do
      nil -> nil
      nested -> nested_value(nested, rest)
    end
  end

  defp nested_value(_other, _keys), do: nil

  defp duration_since(started_at) when is_integer(started_at) do
    max(0, System.monotonic_time() - started_at)
  end

  defp duration_since(%DateTime{} = started_at) do
    diff_ms = DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
    max(0, System.convert_time_unit(diff_ms, :millisecond, :native))
  end

  defp duration_since(_), do: 0
end
