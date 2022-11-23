#
# This file is part of Edgehog.
#
# Copyright 2022 SECO Mind Srl
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

defmodule Edgehog.Repo.Migrations.DropDevicesPartNumberFkey do
  use Ecto.Migration
  import Ecto.Query

  def up do
    drop constraint(:devices, "devices_part_number_fkey")
  end

  def down do
    # to re-create foreign key on devices part_number we have set to nil
    # all device part_numbers which does not exist in system_model_part_numbers
    query =
      from(d in "devices",
        left_join: smpn in "system_model_part_numbers",
        on: d.part_number == smpn.part_number and d.tenant_id == smpn.tenant_id,
        select: d.id,
        where: not is_nil(d.part_number) and is_nil(smpn.part_number)
      )

    device_ids = Edgehog.Repo.all(query, skip_tenant_id: true)

    from(d in "devices", where: d.id in ^device_ids)
    |> Edgehog.Repo.update_all([set: [part_number: nil]], skip_tenant_id: true)

    alter table(:devices) do
      modify :part_number,
             references(:system_model_part_numbers,
               column: :part_number,
               type: :string,
               with: [tenant_id: :tenant_id],
               on_delete: :nothing
             )
    end
  end
end
