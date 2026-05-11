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

defmodule Edgehog.Auth.Providers.OpenFGAIntegrationTests do
  @moduledoc """
  OpenFGA integration tests

  These tests have as prerequisite a running instance of OpenFGA and environment
  variables properly set:

  - OPENFGA_GRPC_ENDPOINT :: with the openfga grpc endpoint (usually localhost:8081 works)
  - OPENFGA_STORE_ID      :: with the store id configured with the model. Check OpenFGA docs on how to properly setup a store
  - AUTHZ_PROVIDER        :: must be openfga for these tests to work
  """

  use Edgehog.Auth.AuthzCase, async: true

  import Edgehog.TenantsFixtures
  import Edgehog.AstarteFixtures

  alias Edgehog.Auth.Providers.OpenFGA
  alias Edgehog.TupleFixtures

  @moduletag :integration_openfga

  test "init_context/1 properly inits a connection with OpenFGA" do
    config = Edgehog.Config.authz_config!()[:config]

    {:ok, ctx} = OpenFGA.init_context(config)

    assert ctx.store_id == config[:store_id]
  end

  describe "write/2" do
    setup do
      config = Edgehog.Config.authz_config!()[:config]

      {:ok, ctx} = OpenFGA.init_context(config)

      %{context: ctx}
    end

    test "Writes correct tuples", %{context: context} do
      opts = [
        subj_type: "user",
        subj_id: System.unique_integer([:positive]),
        rel: "owner",
        obj_type: "tenant",
        obj_id: "test"
      ]

      tuple = TupleFixtures.tuple(opts)

      assert {:ok, _} = OpenFGA.write(tuple, context)
    end

    test "is invoked correctly after operations with Ash", %{context: context} do
      tenant = tenant_fixture()
      realm = realm_fixture(tenant: tenant)

      assert {:ok, %{objects: [object]}} =
               OpenFGA.list_objects({"tenant:#{tenant.slug}", "tenant", "realm"}, context)

      assert "realm:#{realm.name}" == object
    end
  end

  describe "delete/2" do
    setup do
      config = Edgehog.Config.authz_config!()[:config]

      {:ok, ctx} = OpenFGA.init_context(config)

      %{context: ctx}
    end

    test "Deletes correct tuples", %{context: context} do
      opts = [
        subj_type: "user",
        subj_id: System.unique_integer([:positive]),
        rel: "owner",
        obj_type: "tenant",
        obj_id: "test"
      ]

      tuple = TupleFixtures.tuple(opts)
      {:ok, _} = OpenFGA.write(tuple, context)

      assert {:ok, _} = OpenFGA.delete(tuple, context)
    end

    test "is invoked correctly after operations with Ash", %{context: context} do
      tenant = tenant_fixture()
      tenant_fga_id = "tenant:#{tenant.slug}"
      realm = realm_fixture(tenant: tenant)

      assert {:ok, %{objects: [object]}} =
               OpenFGA.list_objects({tenant_fga_id, "tenant", "realm"}, context)

      assert "realm:#{realm.name}" == object

      Ash.destroy!(realm, tenant: tenant)

      assert {:ok, %{objects: []}} =
               OpenFGA.list_objects({tenant_fga_id, "tenant", "realm"}, context)
    end
  end

  describe "check/2" do
    setup do
      config = Edgehog.Config.authz_config!()[:config]

      {:ok, ctx} = OpenFGA.init_context(config)

      %{context: ctx}
    end

    test "false on invalid tuples", %{context: context} do
      opts = [
        subj_type: "user",
        subj_id: System.unique_integer([:positive]),
        rel: "owner",
        obj_type: "tenant",
        obj_id: "test"
      ]

      tuple = TupleFixtures.tuple(opts)

      assert {:ok, false} = OpenFGA.check(tuple, context)
    end
  end
end
