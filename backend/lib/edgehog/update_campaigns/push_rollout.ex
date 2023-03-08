#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.UpdateCampaigns.PushRollout do
  use Ecto.Schema
  import Ecto.Changeset
  alias Edgehog.UpdateCampaigns.PushRollout

  embedded_schema do
    field :force_downgrade, :boolean
    field :max_errors_percentage, :float
    field :max_in_progress_updates, :integer
    field :ota_request_retries, :integer
    field :ota_request_timeout_seconds, :integer
  end

  @doc false
  def changeset(%PushRollout{} = push_rollout, attrs) do
    push_rollout
    |> cast(attrs, [
      :force_downgrade,
      :max_errors_percentage,
      :max_in_progress_updates,
      :ota_request_retries,
      :ota_request_timeout_seconds
    ])
    |> validate_required([
      :force_downgrade,
      :max_errors_percentage,
      :max_in_progress_updates,
      :ota_request_retries,
      :ota_request_timeout_seconds
    ])
  end
end
