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

  alias Edgehog.Files.FileDownloadRequest

  @doc """
  Generate a unique file name.
  """
  def unique_file_name, do: "file-#{System.unique_integer([:positive])}.bin"

  @doc """
  Generate a unique repository name.
  """
  def unique_repository_name, do: "Repository #{System.unique_integer([:positive])}"

  @doc """
  Generate a unique repository handle.
  """
  def unique_repository_handle, do: "repo-#{System.unique_integer([:positive])}"

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
  Generate a file download request fixture.

  ## Options

    * `:tenant` - (required) The tenant to create the file download request for
    * `:device_id` - The device ID (default: auto-creates a new device)
    * `:url` - Download URL (default: auto-generated)
    * `:file_name` - File name (default: auto-generated unique name)
    * `:uncompressed_file_size_bytes` - File size in bytes (default: random)
    * `:digest` - Content digest (default: auto-generated sha256)
    * `:encoding` - Encoding type (default: "")
    * `:ttl_seconds` - TTL (default: 0)
    * `:file_mode` - POSIX file mode (default: random)
    * `:user_id` - POSIX user ID (default: random)
    * `:group_id` - POSIX group ID (default: random)
    * `:destination_type` - Destination type (default: "storage")
    * `:destination` - Destination-specific information (default: nil)
    * `:progress_tracked` - Progress reporting flag (default: false)
    * `:status` - Status (default: nil)
    * `:manual?` - Whether initiated manually (default: true)
  """
  def manual_file_download_request_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant] |> Edgehog.DevicesFixtures.device_fixture() |> Map.fetch!(:id)
      end)

    params =
      Enum.into(opts, %{
        url: "https://example.com/ephemeral/#{System.unique_integer([:positive])}.bin",
        file_name: unique_file_name(),
        uncompressed_file_size_bytes: :rand.uniform(1_000_000),
        digest: unique_file_digest(),
        encoding: "",
        ttl_seconds: 0,
        file_mode: random_file_mode(),
        user_id: random_user_id(),
        group_id: random_group_id(),
        destination_type: "storage",
        destination: nil,
        progress_tracked: false,
        manual?: true,
        device_id: device_id
      })

    FileDownloadRequest
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
    |> Ash.create!()
  end

  def managed_file_download_request_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant] |> Edgehog.DevicesFixtures.device_fixture() |> Map.fetch!(:id)
      end)

    {repository_id, opts} =
      Keyword.pop_lazy(opts, :repository_id, fn ->
        [tenant: tenant] |> repository_fixture() |> Map.fetch!(:id)
      end)

    {file, opts} =
      Keyword.pop_lazy(opts, :file, fn ->
        file_fixture(tenant: tenant, repository_id: repository_id)
      end)

    tenant_id = tenant.tenant_id
    filename = file.name

    params =
      Enum.into(opts, %{
        url:
          "https://example.com/uploads/tenants/#{tenant_id}/repositories/#{repository_id}/files/#{filename}",
        file_name: filename,
        uncompressed_file_size_bytes: file.size,
        digest: file.digest,
        encoding: "",
        ttl_seconds: 0,
        file_mode: random_file_mode(),
        user_id: random_user_id(),
        group_id: random_group_id(),
        destination_type: "storage",
        destination: nil,
        progress_tracked: false,
        manual?: false,
        device_id: device_id
      })

    FileDownloadRequest
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generate a file upload request fixture.

  ## Options

    * `:tenant` - (required) The tenant to create the file upload request for
    * `:device_id` - The device ID (default: auto-creates a new device)
    * `:url` - Upload URL (default: auto-generated)
    * `:source` - Device source path/type (default: "storage")
    * `:encoding` - Encoding type (default: "")
    * `:progress_tracked` - Progress reporting flag (default: false)
    * `:status` - Status (default: :pending)
    * `:source_type` - Source type (default: "filesystem")
    * `:progress_percentage` - Progress percentage (default: 0)
    * `:response_code` - Response code (default: nil)
    * `:response_message` - Response message (default: nil)
    * `:http_headers` - HTTP headers map (default: %{})
  """
  def file_upload_request_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        [tenant: tenant] |> Edgehog.DevicesFixtures.device_fixture() |> Map.fetch!(:id)
      end)

    params =
      Enum.into(opts, %{
        url: "https://example.com/upload/#{System.unique_integer([:positive])}.bin",
        source: "storage",
        encoding: "",
        progress_tracked: false,
        status: :pending,
        source_type: "filesystem",
        progress_percentage: 0,
        http_headers: %{},
        device_id: device_id
      })

    Edgehog.Files.FileUploadRequest
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generate a repository fixture.

  ## Options

    * `:tenant` - (required) The tenant to create the repository for
    * `:name` - Repository name (default: auto-generated unique name)
    * `:handle` - Repository handle (default: auto-generated unique handle)
    * `:description` - Optional description
  """
  def repository_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params =
      Enum.into(opts, %{
        name: unique_repository_name(),
        handle: unique_repository_handle()
      })

    Edgehog.Files.Repository
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
    |> Ash.create!()
  end

  @doc """
  Generate a file with configurable POSIX metadata.

  ## Options

    * `:tenant` - (required) The tenant to create the file for
    * `:repository_id` - The repository ID (default: auto-creates a new repository)
    * `:name` - File name (default: auto-generated unique name)
    * `:size` - File size in bytes (default: random between 1 and 1,000,000)
    * `:digest` - Content digest in format "algorithm:hash" (default: auto-generated sha256)
  """
  def file_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {repository_id, opts} =
      Keyword.pop_lazy(opts, :repository_id, fn ->
        [tenant: tenant] |> repository_fixture() |> Map.fetch!(:id)
      end)

    params =
      Enum.into(opts, %{
        name: unique_file_name(),
        size: :rand.uniform(1_000_000),
        digest: unique_file_digest(),
        repository_id: repository_id
      })

    Edgehog.Files.File
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
    |> Ash.create!()
  end
end
