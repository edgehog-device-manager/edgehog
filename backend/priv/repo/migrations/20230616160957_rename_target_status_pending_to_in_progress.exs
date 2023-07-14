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

defmodule Edgehog.Repo.Migrations.RenameTargetStatusPendingToInProgress do
  use Ecto.Migration

  import Ecto.Query
  alias Edgehog.Repo

  def up do
    from(uct in "update_campaign_targets",
      where: uct.status == "pending",
      update: [set: [status: "in_progress"]]
    )
    |> Repo.update_all([], skip_tenant_id: true)
  end

  def down do
    from(uct in "update_campaign_targets",
      where: uct.status == "in_progress",
      update: [set: [status: "pending"]]
    )
    |> Repo.update_all([], skip_tenant_id: true)
  end
end
