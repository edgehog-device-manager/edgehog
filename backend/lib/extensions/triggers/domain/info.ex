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

defmodule Ash.Astarte.Triggers.Domain.Info do
  @moduledoc """
  Triggers extension domain introspection.

  A collection of helper functions to inspect `Trigger` domains.
  """

  alias Spark.Dsl.Extension

  def triggers(nil), do: []

  def triggers(domain) do
    Extension.get_entities(domain, [:triggers])
  end

  def fallback_handlers(domain) do
    Extension.get_entities(domain, [:fallback_handlers])
  end

  def get_reference_module(reference) do
    Map.get(reference, :module)
  end
end
