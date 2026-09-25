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

defmodule Edgehog.Containers.EnvFile.Provisioner do
  @moduledoc """
  The provisioner for env files.

  Provisioning an env file means ensuring the backing file is available on
  the device (creating a file download request for uploaded files when
  needed) and then sending a `CreateEnvFileRequest` to the device.

  For more information, check the `Edgehog.Containers.Provisioner` docs.
  """
  use Edgehog.Containers.Provisioner,
    resource: Edgehog.Containers.EnvFile,
    core: Edgehog.Containers.EnvFile.Provisioner.Core

  @sup Edgehog.Containers.EnvFile.Provisioner.Supervisor
end
