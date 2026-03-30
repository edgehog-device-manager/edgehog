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

defmodule Edgehog.Auth.Providers.None do
  @moduledoc """
  Inept authz provider. It just allows every query. Kept for retrocompatibility
  """

  @behaviour Edgehog.Auth.Providers.Behaviour

  require Logger

  @impl Edgehog.Auth.Providers.Behaviour
  def init_context(_args) do
    # We do not need a context in this case
    {:ok, []}
  end

  @impl Edgehog.Auth.Providers.Behaviour
  def check({subj, rel, obj}, context) do
    Logger.debug("Authorizing tuple {#{subj}, #{rel}, #{obj}}.")

    {:ok, context}
  end
end
