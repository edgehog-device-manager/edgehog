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

defmodule Edgehog.ContainersFixtures do
  @moduledoc """
  This module defines test helpers for creating 
  entities via the `Edgehog.Containers` context.
  """
  alias Edgehog.Containers.Application
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Release

  @doc """
  Generate a unique application name.
  """
  def unique_application_name, do: "application#{System.unique_integer()}"

  @doc """
  Generate a unique application release version.
  """
  def unique_release_version, do: "0.0.#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique image_credentials name.
  """
  def unique_image_credentials_label, do: "some-label#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique image_credentials username.
  """
  def unique_image_credentials_username, do: "some-username#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique image_credentials password.
  """
  def unique_image_credentials_password, do: "some-password#{System.unique_integer([:positive])}"

  @doc """
  Generate a %ImageCredentials{}.
  """
  def image_credentials_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params =
      Enum.into(opts, %{
        label: unique_image_credentials_label(),
        username: unique_image_credentials_username(),
        password: unique_image_credentials_password()
      })

    Edgehog.Containers.ImageCredentials
    |> Ash.Changeset.for_create(
      :create,
      params,
      tenant: tenant
    )
    |> Ash.create!()
  end

  @doc """
  Generate an %Application{}.
  """
  def application_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params =
      Enum.into(opts, %{
        name: unique_application_name()
      })

    Ash.create!(Application, params, tenant: tenant)
  end

  @doc """
  Generate a %Release{}.
  """
  def release_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {application_id, opts} =
      Keyword.pop_lazy(opts, :application_id, fn -> application_fixture(tenant: tenant).id end)

    params =
      Enum.into(opts, %{
        application_id: application_id,
        version: unique_release_version()
      })

    Ash.create!(Release, params, tenant: tenant)
  end

  @doc """
  Generate a %Deployment{}.
  """
  def deployment_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        Edgehog.DevicesFixtures.device_fixture(tenant: tenant).id
      end)

    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn -> release_fixture(tenant: tenant).id end)

    params =
      Enum.into(opts, %{
        device_id: device_id,
        release_id: release_id
      })

    Ash.create!(Deployment, params, tenant: tenant)
  end
end
