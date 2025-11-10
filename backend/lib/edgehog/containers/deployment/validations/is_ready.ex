#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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
defmodule Edgehog.Containers.Deployment.Validations.IsReady do
  @moduledoc false
  use Ash.Resource.Validation

  @impl Ash.Resource.Validation
  def validate(changeset, opts, _context) do
    {:ok, deployment} = Ash.load(changeset.data, :is_ready)
    readiness = Keyword.get(opts, :readiness, true)

    if deployment.is_ready == readiness,
      do: :ok,
      else: {:error, "This action cannot be performed because the deployment has not the desired readiness."}
  end
end
