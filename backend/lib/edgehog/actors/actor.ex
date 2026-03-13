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

defmodule Edgehog.Actors.Actor do
  @moduledoc """
  Edgheog Actors.
  This module represents an actor performing a call trough the GraphQL APIs.
  """

  use Ash.Resource,
    domain: Edgehog.Actors

  actions do
    defaults [:read]

    create :from_claims do
      accept [:claims]
    end
  end

  attributes do
    attribute :claims, :map, allow_nil?: false
  end
end
