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

defmodule Edgehog.Repo.Migrations.AddPublicKeyToTenants do
  use Ecto.Migration

  def up do
    # Add an empty string as default and then remove it so we handle existing tenants.
    # A real public key must be added afterwards manually.
    alter table(:tenants) do
      add :public_key, :text, null: false, default: ""
    end

    alter table(:tenants) do
      modify :public_key, :text, null: false, default: nil
    end
  end

  def down do
    alter table(:tenants) do
      remove :public_key
    end
  end
end
