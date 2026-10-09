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

defmodule Edgehog.Files.PromExPlugin do
  @moduledoc """
  PromEx plugin for the Edgehog files feature.

  Exposes the following metric groups:

  - `:files_file_download_request_event_metrics` exposing the lifecycle of file download requests:
    - `edgehog_files_file_download_request_started_total`
    - `edgehog_files_file_download_request_completed_total` (labeled by `result`, `reason`)
    - `edgehog_files_file_download_request_duration_seconds` (labeled by `result`, `reason`)
    - `edgehog_files_file_download_request_retries`

  - `:files_file_upload_request_event_metrics` exposing the lifecycle of file upload requests:
    - `edgehog_files_file_upload_request_started_total`
    - `edgehog_files_file_upload_request_completed_total` (labeled by `result`, `reason`)
    - `edgehog_files_file_upload_request_duration_seconds` (labeled by `result`, `reason`)
    - `edgehog_files_file_upload_request_retries`
  """

  use PromEx.Plugin

  alias Edgehog.Files.Telemetry

  @impl PromEx.Plugin
  def event_metrics(_opts) do
    [
      file_download_request_event_metrics(),
      file_upload_request_event_metrics()
    ]
  end

  defp file_download_request_event_metrics do
    metric_prefix = [:edgehog, :files, :file_download_request]

    Event.build(
      :files_file_download_request_event_metrics,
      [
        counter(
          metric_prefix ++ [:started, :total],
          event_name: Telemetry.file_download_start_event(),
          measurement: :count,
          description: "Number of file download requests started on a device.",
          tags: [:destination_type, :request_id, :device_id, :file_id, :tenant_slug],
          tag_values: &download_tag_values/1
        ),
        counter(
          metric_prefix ++ [:completed, :total],
          event_name: Telemetry.file_download_stop_event(),
          measurement: :count,
          description: "Number of file download requests completed on a device.",
          tags: [
            :destination_type,
            :request_id,
            :device_id,
            :file_id,
            :result,
            :reason,
            :tenant_slug
          ],
          tag_values: &download_tag_values/1
        ),
        distribution(
          metric_prefix ++ [:duration, :seconds],
          event_name: Telemetry.file_download_stop_event(),
          measurement: :duration,
          description: "The time it took for a file download request to complete.",
          tags: [:destination_type, :device_id, :result, :reason, :tenant_slug],
          tag_values: &download_tag_values/1,
          reporter_options: [buckets: [100, 250, 500, 1000, 2500, 5000, 10_000, 60_000]],
          unit: {:native, :second}
        ),
        last_value(
          metric_prefix ++ [:retries],
          event_name: Telemetry.file_download_stop_event(),
          measurement: :retries,
          description: "The number of retries it took for a file download request to complete.",
          tags: [:destination_type, :device_id, :result, :tenant_slug],
          tag_values: &download_tag_values/1
        )
      ]
    )
  end

  defp file_upload_request_event_metrics do
    metric_prefix = [:edgehog, :files, :file_upload_request]

    Event.build(
      :files_file_upload_request_event_metrics,
      [
        counter(
          metric_prefix ++ [:started, :total],
          event_name: Telemetry.file_upload_start_event(),
          measurement: :count,
          description: "Number of file upload requests started on a device.",
          tags: [:source_type, :request_id, :device_id, :tenant_slug],
          tag_values: &upload_tag_values/1
        ),
        counter(
          metric_prefix ++ [:completed, :total],
          event_name: Telemetry.file_upload_stop_event(),
          measurement: :count,
          description: "Number of file upload requests completed on a device.",
          tags: [:source_type, :request_id, :device_id, :result, :reason, :tenant_slug],
          tag_values: &upload_tag_values/1
        ),
        distribution(
          metric_prefix ++ [:duration, :seconds],
          event_name: Telemetry.file_upload_stop_event(),
          measurement: :duration,
          description: "The time it took for a file upload request to complete.",
          tags: [:source_type, :device_id, :result, :reason, :tenant_slug],
          tag_values: &upload_tag_values/1,
          reporter_options: [buckets: [100, 250, 500, 1000, 2500, 5000, 10_000, 60_000]],
          unit: {:native, :second}
        ),
        last_value(
          metric_prefix ++ [:retries],
          event_name: Telemetry.file_upload_stop_event(),
          measurement: :retries,
          description: "The number of retries it took for a file upload request to complete.",
          tags: [:source_type, :device_id, :result, :tenant_slug],
          tag_values: &upload_tag_values/1
        )
      ]
    )
  end

  defp download_tag_values(metadata) do
    Map.take(metadata, [
      :destination_type,
      :request_id,
      :device_id,
      :file_id,
      :result,
      :reason,
      :tenant_slug
    ])
  end

  defp upload_tag_values(metadata) do
    Map.take(metadata, [
      :source_type,
      :request_id,
      :device_id,
      :result,
      :reason,
      :tenant_slug
    ])
  end
end
