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

defmodule Edgehog.Campaigns.Campaign.Changes.DeleteObanJob do
  @moduledoc false

  use Ash.Resource.Change

  import Ecto.Query

  alias Ash.Resource.Change

  @impl Change
  def change(changeset, _opts, _context) do
    tenant_id = to_string(changeset.to_tenant)
    id = Ash.Changeset.get_data(changeset, :id)

    query =
      from(j in Oban.Job,
        where: fragment("? ->> 'id' = ?", j.args, ^id),
        where: fragment("? ->> 'tenant' = ?", j.args, ^tenant_id)
      )

    job = Edgehog.Repo.one(query)

    if job do
      Oban.delete_job(job)
    end

    changeset
  end
end
