#
# This file is part of Edgehog.
#
# Copyright 2024 - 2025 SECO Mind Srl
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
  alias Edgehog.AstarteFixtures
  alias Edgehog.Containers.Application
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Deployment
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Network
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.Volume

  @doc """
  Generate a unique application name.
  """
  def unique_application_name, do: "application#{System.unique_integer()}"

  @doc """
  Generate a unique application description.
  """
  def unique_application_description, do: "application_description#{System.unique_integer()}"

  @doc """
  Generate a unique container hostname.
  """
  def unique_container_hostname, do: "hostname#{System.unique_integer()}"

  @doc """
  Generate a unique image reference.
  """
  def unique_image_reference, do: "image#{System.unique_integer()}"

  @doc """
  Generate a unique volume target.
  """
  def unique_volume_target, do: "/fixture#{System.unique_integer()}/target"

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

  def network_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params = Map.new(opts)

    Ash.create!(Network, params, tenant: tenant)
  end

  def image_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params =
      Enum.into(opts, %{
        reference: unique_image_reference()
      })

    Ash.create!(Image, params, tenant: tenant)
  end

  def volume_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    params =
      Enum.into(opts, %{
        target: unique_volume_target()
      })

    Ash.create!(Volume, params, tenant: tenant)
  end

  def container_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {image_id, opts} =
      Keyword.pop_lazy(opts, :image_id, fn -> image_fixture(tenant: tenant).id end)

    # number of volumes to associate with the container
    {volumes, opts} = Keyword.pop(opts, :volumes, 0)

    {volume_target, opts} = Keyword.pop(opts, :volume_target, "/fixture/target")
    {volume_label, opts} = Keyword.pop(opts, :volume_label, "label#{System.unique_integer()}")
    volume_params = %{target: volume_target, label: volume_label}
    volumes = Enum.map(1..volumes//1, fn _ -> volume_params end)

    params =
      Enum.into(opts, %{
        image_id: image_id,
        volumes: volumes
      })

    Container
    |> Ash.Changeset.for_create(:create_fixture, params, tenant: tenant)
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

    # number of containers to associate with the release
    {containers, opts} = Keyword.pop(opts, :containers, 0)

    {container_params, opts} = Keyword.pop(opts, :container_params, [])
    container_params = Keyword.put(container_params, :tenant, tenant)

    containers = Enum.map(1..containers//1, fn _ -> container_fixture(container_params) end)

    params =
      Enum.into(opts, %{
        application_id: application_id,
        version: unique_release_version(),
        containers: containers
      })

    Ash.create!(Release, params, tenant: tenant)
  end

  @doc """
  Generate a %Deployment{}.
  """
  def deployment_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {realm_id, opts} =
      case opts[:device_id] do
        nil ->
          Keyword.pop_lazy(opts, :realm_id, fn ->
            AstarteFixtures.realm_fixture(tenant: tenant).id
          end)

        _ ->
          {nil, opts}
      end

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        Edgehog.DevicesFixtures.device_fixture(realm_id: realm_id, tenant: tenant).id
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

  @doc """
  Generate a %Container.Deployment{}
  """
  def container_deployment_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {realm_id, opts} =
      case opts[:device_id] do
        nil ->
          Keyword.pop_lazy(opts, :realm_id, fn ->
            AstarteFixtures.realm_fixture(tenant: tenant).id
          end)

        _ ->
          {nil, Keyword.delete(opts, :realm_id)}
      end

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        Edgehog.DevicesFixtures.device_fixture(realm_id: realm_id, tenant: tenant).id
      end)

    {container_id, opts} =
      Keyword.pop_lazy(opts, :container_id, fn -> container_fixture(tenant: tenant).id end)

    params =
      Enum.into(opts, %{
        device_id: device_id,
        container_id: container_id
      })

    Ash.create!(Container.Deployment, params, tenant: tenant)
  end

  @doc """
  Generate a %Image.Deployment{}
  """
  def image_deployment_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {realm_id, opts} =
      case opts[:device_id] do
        nil ->
          Keyword.pop_lazy(opts, :realm_id, fn ->
            AstarteFixtures.realm_fixture(tenant: tenant).id
          end)

        _ ->
          {nil, Keyword.delete(opts, :realm_id)}
      end

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        Edgehog.DevicesFixtures.device_fixture(realm_id: realm_id, tenant: tenant).id
      end)

    {image_id, opts} =
      Keyword.pop_lazy(opts, :release_id, fn -> image_fixture(tenant: tenant).id end)

    params =
      Enum.into(opts, %{
        device_id: device_id,
        image_id: image_id
      })

    Ash.create!(Image.Deployment, params, tenant: tenant)
  end

  @doc """
  Generate a %Volume.Deployment{}
  """
  def volume_deployment_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {realm_id, opts} =
      case opts[:device_id] do
        nil ->
          Keyword.pop_lazy(opts, :realm_id, fn ->
            AstarteFixtures.realm_fixture(tenant: tenant).id
          end)

        _ ->
          {nil, Keyword.delete(opts, :realm_id)}
      end

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        Edgehog.DevicesFixtures.device_fixture(realm_id: realm_id, tenant: tenant).id
      end)

    {volume_id, opts} =
      Keyword.pop_lazy(opts, :volume_id, fn -> volume_fixture(tenant: tenant).id end)

    params =
      Enum.into(opts, %{
        device_id: device_id,
        volume_id: volume_id
      })

    Ash.create!(Volume.Deployment, params, tenant: tenant)
  end

  @doc """
  Generate a %Network.Deployment{}
  """
  def network_deployment_fixture(opts \\ []) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)

    {realm_id, opts} =
      case opts[:device_id] do
        nil ->
          Keyword.pop_lazy(opts, :realm_id, fn ->
            AstarteFixtures.realm_fixture(tenant: tenant).id
          end)

        _ ->
          {nil, Keyword.delete(opts, :realm_id)}
      end

    {device_id, opts} =
      Keyword.pop_lazy(opts, :device_id, fn ->
        Edgehog.DevicesFixtures.device_fixture(realm_id: realm_id, tenant: tenant).id
      end)

    {network_id, opts} =
      Keyword.pop_lazy(opts, :network_id, fn -> network_fixture(tenant: tenant).id end)

    params =
      Enum.into(opts, %{
        device_id: device_id,
        network_id: network_id
      })

    Ash.create!(Network.Deployment, params, tenant: tenant)
  end
end
