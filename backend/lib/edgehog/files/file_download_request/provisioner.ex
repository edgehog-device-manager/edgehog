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

defmodule Edgehog.Files.FileDownloadRequest.Provisioner do
  @moduledoc """
  The provisioner for file download requests backing container file binds.

  It waits until the device reports the download as completed, so the
  container deployment orchestrator can treat files like any other
  provisioned resource.

  For more information, check the `Edgehog.Containers.Provisioner` docs.
  """
  use Edgehog.Containers.Provisioner,
    resource: Edgehog.Files.FileDownloadRequest,
    core: Edgehog.Files.FileDownloadRequest.Provisioner.Core

  @sup Edgehog.Containers.File.Provisioner.Supervisor
end
