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

defmodule EdgehogWeb.Schema.AllowedRegistriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  allowed registry entities via Ash.
  """

  alias Edgehog.Containers.AllowedRegistry

  @doc """
  Generate a unique allowed registry hostname.
  """
  def unique_allowed_registry do
    "registry-#{System.unique_integer([:positive])}.example.com"
  end

  @doc """
  Generate an allowed registry.
  """
  def allowed_registry_fixture(opts \\ []) do
    {tenant, opts} =
      cond do
        is_map(opts) -> Map.pop!(opts, :tenant)
        Keyword.keyword?(opts) -> Keyword.pop!(opts, :tenant)
      end

    params =
      opts
      |> Enum.into(%{})
      |> Map.put_new_lazy(:registry, &unique_allowed_registry/0)

    AllowedRegistry
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end
end
