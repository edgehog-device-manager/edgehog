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
  Generate a %Deployment{}.
  """
  def deployment_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        Edgehog.DevicesFixtures.device_fixture(tenant: tenant).id
      end)

    # TODO: use release fixture once implemented
    default_release_id = fn ->
      name = "app-#{System.unique_integer()}"
      version = "0.0.#{System.unique_integer([:positive])}"

      app = Ash.create!(Application, %{name: name}, tenant: tenant)
      release = Ash.create!(Release, %{application_id: app.id, version: version}, tenant: tenant)

      release.id
    end

    {release_id, opts} =
      Keyword.pop_lazy(opts, :release_id, default_release_id)

    params =
      Enum.into(opts, %{
        device_id: device_id,
        release_id: release_id
      })

    Ash.create!(Deployment, params, tenant: tenant)
  end
end
