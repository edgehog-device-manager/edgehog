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

defmodule Edgehog.TupleFixtures do
  @moduledoc """
  Authz tuple fixtures.

  This module gives to tests the ability to generate valid (or invalid) tuples. Resolve to function docs for more accurate descriptions.
  """

  @doc """
  Generate a unique subject type
  """
  def unique_subject_type, do: "type-#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique subject id
  """
  def unique_subject_id, do: "subj-id-#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique object type
  """
  def unique_object_type, do: "type-#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique object id
  """
  def unique_object_id, do: "obj-id-#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique relationship
  """
  def unique_relationship, do: "rel-#{System.unique_integer([:positive])}"

  def subject(opts \\ []) do
    subj_type =
      opts
      |> Keyword.get_lazy(:subj_type, &unique_subject_type/0)
      |> to_string()

    subj_id =
      opts
      |> Keyword.get_lazy(:subj_id, &unique_subject_id/0)
      |> to_string()

    "#{subj_type}:#{subj_id}"
  end

  def object(opts \\ []) do
    obj_type =
      opts
      |> Keyword.get_lazy(:obj_type, &unique_object_type/0)
      |> to_string()

    obj_id =
      opts
      |> Keyword.get_lazy(:obj_id, &unique_object_id/0)
      |> to_string()

    "#{obj_type}:#{obj_id}"
  end

  def relationship(opts \\ []) do
    opts
    |> Keyword.get_lazy(:rel, &unique_relationship/0)
    |> to_string()
  end

  def tuple(opts \\ []) do
    subj = subject(opts)
    obj = object(opts)
    rel = relationship(opts)

    {subj, rel, obj}
  end
end
