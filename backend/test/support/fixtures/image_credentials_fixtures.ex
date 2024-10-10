#
# This file is part of Edgehog.
#
# Copyright 2021-2024 SECO Mind Srl
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

defmodule Edgehog.ImageCredentialsFixtures do
  @moduledoc """
  This module defines test helpers for creating 
  entities via the `Edgehog.ImageCredentials` context.
  """

  @doc """
  Generate a unique image_credentials name.
  """
  def unique_image_credentials_name, do: "some-name#{System.unique_integer([:positive])}"

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
        name: unique_image_credentials_name(),
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
end
