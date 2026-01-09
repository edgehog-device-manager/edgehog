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

defmodule EdgehogWeb.SubsCase do
  @moduledoc """
  Test case for subscriptions
  """
  use ExUnit.CaseTemplate

  alias Absinthe.Phoenix.SubscriptionTest
  alias Ecto.Adapters.SQL.Sandbox
  alias EdgehogWeb.Auth.Token

  require Phoenix.ChannelTest

  @endpoint EdgehogWeb.Endpoint
  using do
    quote do
      use Absinthe.Phoenix.SubscriptionTest,
        schema: EdgehogWeb.Schema

      import Edgehog.Assertions
      import EdgehogWeb.SubsCase
      import Phoenix.ChannelTest

      require Phoenix.ChannelTest

      @endpoint EdgehogWeb.Endpoint
    end
  end

  setup tags do
    pid = Sandbox.start_owner!(Edgehog.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  setup [:create_tenant, :auth_socket, :allow_socket_to_repo]

  defp create_tenant(_context) do
    tenant_private_key = X509.PrivateKey.new_ec(:secp256r1)

    tenant_public_key =
      tenant_private_key
      |> X509.PublicKey.derive()
      |> X509.PublicKey.to_pem()

    tenant = Edgehog.TenantsFixtures.tenant_fixture(public_key: tenant_public_key)

    jwk =
      tenant_private_key
      |> X509.PrivateKey.to_pem()
      |> JOSE.JWK.from_pem()

    claims = %{e_tga: true}

    {:ok, jwt, _claims} =
      Token.encode_and_sign("dontcare", claims,
        secret: jwk,
        allowed_algos: ["ES256"]
      )

    %{tenant: tenant, jwt: jwt}
  end

  defp auth_socket(%{tenant: tenant, jwt: jwt}) do
    params = %{
      "token" => "#{jwt}",
      "tenant" => tenant.slug
    }

    {:ok, socket} = Phoenix.ChannelTest.connect(EdgehogWeb.GqlSocket, params)
    {:ok, socket} = SubscriptionTest.join_absinthe(socket)

    %{socket: socket}
  end

  defp auth_socket(_ctx), do: %{}

  defp allow_socket_to_repo(%{socket: socket}) do
    Sandbox.allow(Edgehog.Repo, self(), socket.channel_pid)
    Sandbox.allow(Edgehog.Repo, self(), Process.whereis(AshGraphql.Subscription.Batcher))

    :ok
  end
end
