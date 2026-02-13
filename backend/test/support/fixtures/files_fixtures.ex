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

defmodule Edgehog.FilesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Files` domain.
  """

  @doc """
  Generate a unique file name.
  """
  def unique_file_name, do: "file-#{System.unique_integer([:positive])}.bin"

  @doc """
  Generate a unique file digest.
  """
  def unique_file_digest do
    hash = 32 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
    "sha256:#{hash}"
  end

  @doc """
  Generate a random file mode.
  """
  def random_file_mode do
    [:regular, :executable, :private, :shared_writable, :world_writable]
    |> Enum.random()
    |> file_mode()
  end

  @doc """
  Generate a random user ID.
  """
  def random_user_id do
    [:root, :regular, :system]
    |> Enum.random()
    |> user_id()
  end

  @doc """
  Generate a random group ID.
  """
  def random_group_id do
    [:root, :regular, :system]
    |> Enum.random()
    |> group_id()
  end

  @doc """
  Returns a POSIX file permission mode for the given type.

  ## Options

    * `:regular` - 0o644  (rw-r--r--) (owner: read/write, group: read, others: read)
    * `:executable` - 0o755  (rwxr-xr-x) (owner: read/write/execute, group: read/execute, others: read/execute)
    * `:private` - 0o600  (rw-------) (owner: read/write, group: none, others: none)
    * `:shared_writable` - 0o664  (rw-rw-r--) (owner: read/write, group: read/write, others: read)
    * `:world_writable` - 0o666  (rw-rw-rw-) (owner: read/write, group: read/write, others: read/write)
  """
  def file_mode(type \\ :regular)
  def file_mode(:regular), do: 0o644
  def file_mode(:executable), do: 0o755
  def file_mode(:private), do: 0o600
  def file_mode(:shared_writable), do: 0o664
  def file_mode(:world_writable), do: 0o666

  @doc """
  Returns a POSIX user ID (UID) for the given type.

  ## Options

    * `:root` - UID 0 - root user (superuser with all privileges)
    * `:regular` - UID 1000 - First regular user on Linux systems
    * `:system` - UID 999 - Unprivileged service account
  """
  def user_id(type \\ :root)
  def user_id(:root), do: 0
  def user_id(:regular), do: 1000
  def user_id(:system), do: 999

  @doc """
  Returns a POSIX group ID (GID) for the given type.

  ## Options

    * `:root` - GID 0 - root/wheel administrative group
    * `:regular` - GID 1000 - typically the first regular user's primary group
    * `:system` - GID 999 - system group for service accounts
  """
  def group_id(type \\ :root)
  def group_id(:root), do: 0
  def group_id(:regular), do: 1000
  def group_id(:system), do: 999

  @doc """
  Generate a file with configurable POSIX metadata.

  ## Options

    * `:tenant` - (required) The tenant to create the file for
    * `:name` - File name (default: auto-generated unique name)
    * `:size` - File size in bytes (default: random between 1 and 1,000,000)
    * `:digest` - Content digest in format "algorithm:hash" (default: auto-generated sha256)
    * `:mode` - POSIX file permissions (default: 0o644 for regular file)
    * `:user_id` - POSIX user ID/UID (default: 0 for root)
    * `:group_id` - POSIX group ID/GID (default: 0 for root group)
    * `:url` - Download URL (default: auto-generated example.com URL)
  """
  def file_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params =
      Enum.into(opts, %{
        name: unique_file_name(),
        size: :rand.uniform(1_000_000),
        digest: unique_file_digest(),
        mode: random_file_mode(),
        user_id: random_user_id(),
        group_id: random_group_id(),
        url: "https://example.com/files/#{System.unique_integer([:positive])}.bin"
      })

    Edgehog.Files.File
    |> Ash.Changeset.for_create(:create, params, tenant: tenant)
    |> Ash.create!()
  end
end
