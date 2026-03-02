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

defmodule Edgehog.Repo.Migrations.RemoveOldStateValues do
  @moduledoc """
  Updates values in the `deployment` table. Old state values might interfere with the correct behavior of edgehog, as incorrect states cannot be displayed by graphql (and fail matches in trigger handling).
  This migration sets the most plausible actual state of deployments, relying on the fact that the container reconciler will eventually run for interesting (online) devices and will solve the actual state of applications.

  Rationale:
  - starting -> started :: deployments marked as `starting` should eventually have been started.
  - stopping -> stopped :: similarly to previous, stopping deployments eventually actually stopped.
  - error -> stopped :: errored deployments were marked as such because something went wrong. The actual state is stopped, and the device emitted an `:error` event
  - deleting -> stopped :: in-deletion deployments have either been deleted (in this case they are stopped and cannot even run) or not (something went wrong on the device side). In either case they are not running anymore, and the reconsiler should choose what to do with these deployments.
  """

  use Ecto.Migration

  def up do
    Ecto.Migration.execute("""
    UPDATE application_deployments
    SET state = 'stopped'
    WHERE state = 'stopping' OR state = 'error' OR state = 'deleting';
    """)

    Ecto.Migration.execute("""
    UPDATE application_deployments
    SET state = 'started'
    WHERE state = 'starting';
    """)
  end
end
