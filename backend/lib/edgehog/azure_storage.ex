#
# This file is part of Edgehog.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Edgehog.AzureStorage do
  @moduledoc """
  Waffle module for Azure storage compatibility.

  Inspiration taken from waffle's s3 module
  https://github.com/elixir-waffle/waffle/blob/8b058e5e4aabe29481df16ab691f8d1ffce6b6fd/lib/waffle/storage/s3.ex
  """

  alias Azurex.Blob
  alias Waffle.Definition.Versioning

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    name = Path.join(destination_dir, file.file_name)
    container = container(definition, {file, scope})

    content_type =
      version |> definition.s3_object_headers({file, scope}) |> Keyword.get(:content_type)

    contents =
      case file do
        %Waffle.File{binary: file_binary} when is_binary(file_binary) -> file_binary
        %Waffle.File{path: file_path} -> {:stream, File.stream!(file_path)}
      end

    with :ok <- Blob.put_blob(name, contents, content_type, container) do
      {:ok, file.file_name}
    end
  end

  def delete(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    filename = Path.basename(file.file_name)
    name = Path.join(destination_dir, filename)
    container = container(definition, {file, scope})

    Blob.delete_blob(name, container)

    :ok
  end

  def url(definition, version, file_and_scope, _options \\ []) do
    host = host(definition, file_and_scope)
    dir = definition.storage_dir(version, file_and_scope)
    filename = Versioning.resolve_file_name(definition, version, file_and_scope)
    container = container(definition, file_and_scope)

    # TODO: replace with Blob.get_url when https://github.com/jakobht/azurex/pull/47 is merged
    # and we can specify a custom api_url
    Path.join([host, container, dir, filename])
  end

  defp container(definition, file_and_scope) do
    file_and_scope |> definition.bucket() |> parse_container()
  end

  defp parse_container({:system, env_var}) when is_binary(env_var), do: System.get_env(env_var)
  defp parse_container(name), do: name

  defp host(definition, file_and_scope) do
    case asset_host(definition, file_and_scope) do
      {:system, env_var} when is_binary(env_var) -> System.get_env(env_var)
      url -> url
    end
  end

  defp asset_host(definition, _file_and_scope) do
    case definition.asset_host() do
      false -> Blob.Config.api_url()
      nil -> Blob.Config.api_url()
      host -> host
    end
  end
end
