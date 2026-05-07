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

defmodule Edgehog.Auth.AuthzCase do
  @moduledoc """
  This module defines a test case for all those tests that should test for
  authorization integration with an `FGAService`.

  Typically we test up to the provider, then test the provider and finally test
  integration per provider. This way we ensure that every step of the authz
  chain can be trusted

  This case if for tests in the first step: up to the provider:
  - sets up a database connection
  - sets up a tenant and a realm
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL

  using do
    quote do
      use Mimic

      import Edgehog.Auth.AuthzCase
    end
  end

  setup tags do
    pid = SQL.Sandbox.start_owner!(Edgehog.Repo, shared: not tags[:async])
    on_exit(fn -> SQL.Sandbox.stop_owner(pid) end)

    # We manually generate the keypair so we can sign a JWT with it below
    tenant_private_key = X509.PrivateKey.new_ec(:secp256r1)

    tenant_public_key =
      tenant_private_key
      |> X509.PublicKey.derive()
      |> X509.PublicKey.to_pem()

    # Create a tenant fixture
    tenant = Edgehog.TenantsFixtures.tenant_fixture(public_key: tenant_public_key)
    realm = Edgehog.AstarteFixtures.realm_fixture(tenant: tenant)

    %{tenant: tenant, realm: realm}
  end
end
