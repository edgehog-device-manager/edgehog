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

  For more information, check the `Edgehog.Provisioner.Core.Behaviour` docs.
  """
  use Edgehog.Provisioner.Core

  alias Edgehog.Files

  @impl Edgehog.Provisioner.Core.Behaviour
  def ready?(%{status: status}), do: status == :completed

  @impl Edgehog.Provisioner.Core.Behaviour
  def topic(%{id: id}), do: "ready:file_download_requests:#{id}"
  def topic(id), do: "ready:file_download_requests:#{id}"

  @impl Edgehog.Provisioner.Core.Behaviour
  def subscribe_topic(%{id: id}), do: "file_download_requests:#{id}"
  def subscribe_topic(id), do: "file_download_requests:#{id}"

  @impl Edgehog.Provisioner.Core.Behaviour
  def name(%{id: id}),
    do: {:via, Registry, {Edgehog.Files.FileDownloadRequest.Provisioner.Registry, id}}

  @impl Edgehog.Provisioner.Core.Behaviour



  @impl Edgehog.Provisioner.Core.Behaviour
  def send_to_device(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    Files.send_file_download_request(resource, tenant: tenant)
  end

  @impl Edgehog.Provisioner.Core.Behaviour
  def reconcile(resource, opts) do
    tenant = Keyword.fetch!(opts, :tenant)

    with {:error, _} <- Files.fetch_file_download_request(resource.id, tenant: tenant),
         do: :not_found
  end
end
