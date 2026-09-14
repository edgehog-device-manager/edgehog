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

defmodule Edgehog.Files.FileDownloadRequest.Provisioner.Core do
  @moduledoc """
  The module describing the Core functions required by the file download
  request provisioner.

  It allows the container deployment orchestrator to wait for the files
  backing target-less file binds like any other provisioned resource: the
  provisioner broadcasts readiness once the device reports the download as
  completed, and a failure if the provisioning deadline is hit.

  For more information, check the `Edgehog.Containers.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Containers.Provisioner.Core

  alias Edgehog.Files

  require Logger

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def ready?(%{status: status}), do: status == :completed

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "ready:file_download_requests:#{id}"
  def topic(id), do: "ready:file_download_requests:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "file_download_requests:#{id}"
  def subscribe_topic(id), do: "file_download_requests:#{id}"

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Files.FileDownloadRequest.Provisioner.Registry, id}}

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def send_to_device(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    case Files.send_file_download_request(resource, tenant: tenant) do
      {:ok, _} -> :ok
      {:error, _reason} = error -> error
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def reconcile(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    case Files.fetch_file_download_request(resource.id, tenant: tenant) do
      {:ok, fresh_resource} -> {:ok, fresh_resource}
      {:error, _} -> :not_found
    end
  end

  # Logging functions

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_started(resource, device) do
    Logger.info("""
    File download request #{resource.id} provisioned on device #{device.device_id}. Waiting events
    """)
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_api_error(resource, error) do
    if temporary_error?(error) do
      Logger.warning(
        "Error while sending the file download request #{resource.id}: #{inspect(error)}. The operation will be retried shortly."
      )
    else
      Logger.error(
        "Unrecoverable error while sending the file download request #{resource.id}: #{inspect(error)}. Terminating."
      )
    end
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_failed(resource, reason) do
    Logger.info(
      "Provisioner for file download request #{resource.id} gave up with reason #{inspect(reason)}."
    )
  end

  @impl Edgehog.Containers.Provisioner.Core.Behaviour
  def log_provisioning_completed(resource, retries) do
    Logger.info(
      "File download request #{resource.id} successfully provisioned after #{retries} retries."
    )
  end
end
