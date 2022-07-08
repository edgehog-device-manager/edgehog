#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

defmodule Edgehog.AstarteFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Edgehog.Astarte` context.
  """

  @doc """
  Generate a cluster.
  """
  def cluster_fixture(attrs \\ %{}) do
    {:ok, cluster} =
      attrs
      |> Enum.into(%{
        base_api_url: "https://api.astarte.example.com",
        name: "some name"
      })
      |> Edgehog.Astarte.create_cluster()

    cluster
  end

  @private_key X509.PrivateKey.new_ec(:secp256r1) |> X509.PrivateKey.to_pem()

  @doc """
  Generate a realm.
  """
  def realm_fixture(cluster, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        name: "somename",
        private_key: @private_key
      })

    {:ok, realm} = Edgehog.Astarte.create_realm(cluster, attrs)

    realm
  end

  @doc """
  Generate a random device id
  """
  def random_device_id do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)

    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Generate an %Astarte.Device{}.
  """
  def astarte_device_fixture(realm, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        device_id: random_device_id(),
        name: "some name"
      })

    {:ok, device} = Edgehog.Astarte.create_device(realm, attrs)

    device
  end
end
