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

defmodule Edgehog.Files.FileUploadRequest.Changes.ValidateSource do
  @moduledoc """
  Changes module responsible for validating the `source` field of a `FileUploadRequest`
  based on the `source_type`.
  """

  use Ash.Resource.Change

  alias Ash.Error.Changes.InvalidArgument

  @impl Ash.Resource.Change
  def change(changeset, _opts, _context) do
    source_type = Ash.Changeset.get_attribute(changeset, :source_type)
    source = Ash.Changeset.get_attribute(changeset, :source)

    case validate_source(source_type, source) do
      {:ok, normalized_source} ->
        Ash.Changeset.change_attribute(changeset, :source, normalized_source)

      {:error, reason} ->
        Ash.Changeset.add_error(changeset, reason)
    end
  end

  defp validate_source(:storage, source) do
    case AshGraphql.Resource.decode_relay_id(source) do
      {:ok, %{id: decoded_source}} ->
        {:ok, decoded_source}

      {:error, _reason} ->
        {:error,
         InvalidArgument.exception(
           field: :source,
           message: "invalid storage file id"
         )}
    end
  end

  defp validate_source(_source_type, source), do: {:ok, source}
end
