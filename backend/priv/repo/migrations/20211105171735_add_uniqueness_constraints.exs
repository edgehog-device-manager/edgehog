#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.AddUniquenessConstraints do
  use Ecto.Migration

  def change do
    create unique_index(:tenants, [:name])
    create unique_index(:tenants, [:slug])

    create unique_index(:clusters, [:name])

    create unique_index(:realms, [:name, :tenant_id])

    create unique_index(:devices, [:device_id, :realm_id, :tenant_id])
  end
end
