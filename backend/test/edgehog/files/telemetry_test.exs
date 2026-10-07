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

defmodule Edgehog.Files.TelemetryTest do
  use Edgehog.DataCase, async: false

  import Edgehog.DevicesFixtures
  import Edgehog.FilesFixtures
  import Edgehog.TenantsFixtures
  import Edgehog.TelemetryCapture

  alias Ecto.Adapters.SQL.Sandbox
  alias Edgehog.Files.FileDownloadRequest.Provisioner, as: FileDownloadRequestProvisioner
  alias Edgehog.Files.Telemetry

  @moduletag :telemetry

  describe "event topics" do
    test "returns expected event topic definitions" do
      assert Telemetry.file_download_start_event() == [
               :edgehog,
               :files,
               :file_download_request,
               :start
             ]

      assert Telemetry.file_download_stop_event() == [
               :edgehog,
               :files,
               :file_download_request,
               :stop
             ]

      assert Telemetry.file_upload_start_event() == [
               :edgehog,
               :files,
               :file_upload_request,
               :start
             ]

      assert Telemetry.file_upload_stop_event() == [
               :edgehog,
               :files,
               :file_upload_request,
               :stop
             ]
    end
  end

  describe "file download request telemetry emission" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)

      file_download_request =
        manual_file_download_request_fixture(
          tenant: tenant,
          device_id: device.id,
          destination_type: :storage,
          progress_tracked: true,
          encoding: "gz"
        )

      {:ok, tenant: tenant, device: device, file_download_request: file_download_request}
    end

    test "emits start event with measurements and metadata", ctx do
      start_capture([Telemetry.file_download_start_event()])

      started_at = Telemetry.file_download_request_started(ctx.file_download_request)

      assert is_integer(started_at)

      {measurements, metadata} = assert_receive_event(Telemetry.file_download_start_event())

      assert measurements.count == 1
      assert is_integer(measurements.system_time)
      assert metadata.transfer_type == :download
      assert metadata.destination_type == :storage
      assert metadata.progress_tracked == true
      assert metadata.needs_encoding == true
      assert metadata.request_id == ctx.file_download_request.id
      assert metadata.device_id == ctx.device.id
      assert metadata.started_at == started_at
    end

    test "emits completed stop event with result :ok and duration", ctx do
      start_capture([Telemetry.file_download_stop_event()])

      started_at = System.monotonic_time() - 100_000

      Telemetry.file_download_request_completed(
        ctx.file_download_request,
        [],
        started_at,
        1,
        :ready
      )

      {measurements, metadata} = assert_receive_event(Telemetry.file_download_stop_event())

      assert measurements.count == 1
      assert measurements.retries == 1
      assert measurements.duration >= 100_000
      assert metadata.result == :ok
      assert metadata.reason == :ready
      assert metadata.duration_unit == :native
      assert metadata.transfer_type == :download
      assert metadata.destination_type == :storage
      assert metadata.request_id == ctx.file_download_request.id
      assert metadata.device_id == ctx.device.id
    end

    test "emits failed stop event with result :error and reason", ctx do
      start_capture([Telemetry.file_download_stop_event()])

      started_at = System.monotonic_time() - 50_000

      Telemetry.file_download_request_failed(
        ctx.file_download_request,
        [],
        started_at,
        3,
        :device_offline
      )

      {measurements, metadata} = assert_receive_event(Telemetry.file_download_stop_event())

      assert measurements.count == 1
      assert measurements.retries == 3
      assert measurements.duration >= 50_000
      assert metadata.result == :error
      assert metadata.reason == :device_offline
      assert metadata.duration_unit == :native
      assert metadata.transfer_type == :download
      assert metadata.destination_type == :storage
      assert metadata.request_id == ctx.file_download_request.id
      assert metadata.device_id == ctx.device.id
    end
  end

  describe "file upload request telemetry emission" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)

      file_upload_request =
        file_upload_request_fixture(
          tenant: tenant,
          device_id: device.id,
          source_type: "filesystem",
          progress_tracked: true,
          encoding: "tar.gz"
        )

      {:ok, tenant: tenant, device: device, file_upload_request: file_upload_request}
    end

    test "emits start event with measurements and metadata", ctx do
      start_capture([Telemetry.file_upload_start_event()])

      started_at = Telemetry.file_upload_request_started(ctx.file_upload_request)

      assert is_integer(started_at)

      {measurements, metadata} = assert_receive_event(Telemetry.file_upload_start_event())

      assert measurements.count == 1
      assert is_integer(measurements.system_time)
      assert metadata.transfer_type == :upload
      assert metadata.source_type == :filesystem
      assert metadata.progress_tracked == true
      assert metadata.needs_encoding == true
      assert metadata.request_id == ctx.file_upload_request.id
      assert metadata.device_id == ctx.device.id
      assert metadata.started_at == started_at
    end

    test "emits completed stop event with result :ok and duration", ctx do
      start_capture([Telemetry.file_upload_stop_event()])

      started_at = System.monotonic_time() - 200_000

      Telemetry.file_upload_request_completed(
        ctx.file_upload_request,
        [],
        started_at,
        0,
        :ok
      )

      {measurements, metadata} = assert_receive_event(Telemetry.file_upload_stop_event())

      assert measurements.count == 1
      assert measurements.retries == 0
      assert measurements.duration >= 200_000
      assert metadata.result == :ok
      assert metadata.reason == :ok
      assert metadata.duration_unit == :native
      assert metadata.transfer_type == :upload
      assert metadata.source_type == :filesystem
      assert metadata.request_id == ctx.file_upload_request.id
      assert metadata.device_id == ctx.device.id
    end

    test "emits failed stop event with result :error and reason", ctx do
      start_capture([Telemetry.file_upload_stop_event()])

      started_at = System.monotonic_time() - 80_000

      Telemetry.file_upload_request_failed(
        ctx.file_upload_request,
        [],
        started_at,
        1,
        :connection_refused
      )

      {measurements, metadata} = assert_receive_event(Telemetry.file_upload_stop_event())

      assert measurements.count == 1
      assert measurements.retries == 1
      assert measurements.duration >= 80_000
      assert metadata.result == :error
      assert metadata.reason == :connection_refused
      assert metadata.duration_unit == :native
      assert metadata.transfer_type == :upload
      assert metadata.source_type == :filesystem
      assert metadata.request_id == ctx.file_upload_request.id
      assert metadata.device_id == ctx.device.id
    end
  end

  describe "identifier gating" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)

      file_download_request =
        manual_file_download_request_fixture(
          tenant: tenant,
          device_id: device.id
        )

      on_exit(fn ->
        Edgehog.Config.reload_files_telemetry_include_identifiers()
      end)

      {:ok, tenant: tenant, file_download_request: file_download_request}
    end

    test "excludes request_id, device_id and file_id when include_identifiers is false", ctx do
      Edgehog.Config.put_files_telemetry_include_identifiers(false)
      refute Telemetry.include_identifiers?()

      start_capture([Telemetry.file_download_start_event()])

      Telemetry.file_download_request_started(ctx.file_download_request)

      {_measurements, metadata} = assert_receive_event(Telemetry.file_download_start_event())

      refute Map.has_key?(metadata, :request_id)
      refute Map.has_key?(metadata, :device_id)
      refute Map.has_key?(metadata, :file_id)
      assert metadata.transfer_type == :download
    end
  end

  describe "provisioner telemetry integration" do
    setup do
      tenant = tenant_fixture()
      device = device_fixture(tenant: tenant)

      {:ok, tenant: tenant, device: device}
    end

    test "emits start and completed stop events when download request is already ready", ctx do
      start_capture([
        Telemetry.file_download_start_event(),
        Telemetry.file_download_stop_event()
      ])

      file_download_request =
        manual_file_download_request_fixture(
          tenant: ctx.tenant,
          device_id: ctx.device.id,
          status: :completed
        )

      mark_device_online!(ctx.device, ctx.tenant)

      provisioner =
        case FileDownloadRequestProvisioner.start(
               tenant: ctx.tenant,
               resource: file_download_request,
               mode: :manual
             ) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      Sandbox.allow(Edgehog.Repo, self(), provisioner)
      ref = Process.monitor(provisioner)

      {measurements, metadata} =
        assert_receive_event(Telemetry.file_download_start_event())

      assert measurements.count == 1
      assert metadata.transfer_type == :download
      assert metadata.request_id == file_download_request.id
      assert metadata.device_id == ctx.device.id

      FileDownloadRequestProvisioner.run(provisioner)

      assert_receive {:DOWN, ^ref, :process, ^provisioner, :normal}, 1000

      {measurements, metadata} =
        assert_receive_event(Telemetry.file_download_stop_event())

      assert measurements.count == 1
      assert measurements.retries == 0
      assert is_integer(measurements.duration)
      assert metadata.result == :ok
      assert metadata.reason == :already_ready
      assert metadata.transfer_type == :download
      assert metadata.request_id == file_download_request.id
      assert metadata.device_id == ctx.device.id
    end

    test "emits start and failed stop events when device is offline", ctx do
      start_capture([
        Telemetry.file_download_start_event(),
        Telemetry.file_download_stop_event()
      ])

      file_download_request =
        manual_file_download_request_fixture(
          tenant: ctx.tenant,
          device_id: ctx.device.id,
          status: :completed
        )

      mark_device_offline!(ctx.device, ctx.tenant)

      provisioner =
        case FileDownloadRequestProvisioner.start(
               tenant: ctx.tenant,
               resource: file_download_request,
               mode: :manual
             ) do
          {:ok, pid} -> pid
          {:error, {:already_started, pid}} -> pid
        end

      Sandbox.allow(Edgehog.Repo, self(), provisioner)

      {_measurements, metadata} =
        assert_receive_event(Telemetry.file_download_start_event())

      assert metadata.transfer_type == :download
      assert metadata.request_id == file_download_request.id

      {measurements, metadata} =
        assert_receive_event(Telemetry.file_download_stop_event())

      assert measurements.count == 1
      assert measurements.retries == 0
      assert is_integer(measurements.duration)
      assert metadata.result == :error
      assert metadata.reason == :device_offline
      assert metadata.transfer_type == :download
      assert metadata.request_id == file_download_request.id
    end
  end

  defp mark_device_online!(device, tenant) do
    timestamp = DateTime.now!("Etc/UTC")

    opts = %{
      online: true,
      last_connection: timestamp,
      last_disconnection: timestamp
    }

    device
    |> Ash.Changeset.for_update(:from_device_status, opts)
    |> Ash.update!(tenant: tenant)
  end

  defp mark_device_offline!(device, tenant) do
    timestamp = DateTime.now!("Etc/UTC")

    opts = %{
      online: false,
      last_connection: timestamp,
      last_disconnection: timestamp
    }

    device
    |> Ash.Changeset.for_update(:from_device_status, opts)
    |> Ash.update!(tenant: tenant)
  end
end
