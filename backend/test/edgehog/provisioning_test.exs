#
# This file is part of Edgehog.
#
# Copyright 2023 SECO Mind Srl
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

defmodule Edgehog.ProvisioningTest do
  # This can't be async: true because we're using Mox in global mode
  use Edgehog.DataCase
  use Edgehog.AstarteMockCase

  import Edgehog.AstarteFixtures
  import Edgehog.TenantsFixtures

  alias Astarte.Client.APIError
  alias Edgehog.Astarte
  alias Edgehog.Provisioning
  alias Edgehog.Provisioning.AstarteConfig
  alias Edgehog.Provisioning.TenantConfig
  alias Edgehog.Tenants
  alias Edgehog.Tenants.Reconciler

  @valid_pem_public_key X509.PrivateKey.new_ec(:secp256r1)
                        |> X509.PublicKey.derive()
                        |> X509.PublicKey.to_pem()

  @valid_pem_private_key X509.PrivateKey.new_ec(:secp256r1) |> X509.PrivateKey.to_pem()

  describe "provision_tenant/1" do
    setup do
      # We have to use Mox in global mode because the Interfaces and Triggers mocks are
      # called by an anoymous task launched by the reconciler and we can't easily recover
      # its pid to allow mocks call from it
      Mox.set_mox_global()

      :ok
    end

    test "with valid attrs creates the tenant, cluster and realm" do
      attrs = %{
        name: "Test",
        slug: "test",
        public_key: @valid_pem_public_key,
        astarte_config: %{
          base_api_url: "https://astarte.api.example",
          realm_name: "testrealm",
          realm_private_key: @valid_pem_private_key
        }
      }

      assert {:ok, %TenantConfig{} = tenant_config} =
               wait_for_reconciliation!(fn -> Provisioning.provision_tenant(attrs) end)

      %TenantConfig{
        name: name,
        slug: slug,
        public_key: public_key
      } = tenant_config

      assert name == attrs.name
      assert slug == attrs.slug
      assert public_key == attrs.public_key

      assert {:ok, tenant} = Tenants.fetch_tenant_by_slug(tenant_config.slug)

      assert %Tenants.Tenant{
               name: ^name,
               slug: ^slug,
               public_key: ^public_key
             } = tenant

      tenant_id = tenant.tenant_id

      %AstarteConfig{
        base_api_url: base_api_url,
        realm_name: realm_name,
        realm_private_key: realm_private_key
      } = tenant_config.astarte_config

      assert base_api_url == attrs.astarte_config.base_api_url
      assert realm_name == attrs.astarte_config.realm_name
      assert realm_private_key == attrs.astarte_config.realm_private_key

      assert Astarte.Cluster
             |> Ecto.Query.where(base_api_url: ^base_api_url)
             |> Repo.exists?(skip_tenant_id: true)

      assert {:ok, %Astarte.Realm{tenant_id: ^tenant_id, private_key: ^realm_private_key}} =
               Astarte.fetch_realm_by_name(realm_name)
    end

    test "succeeds when providing the URL of an already existing cluster" do
      cluster = cluster_fixture()

      assert {:ok, _tenant_config} =
               wait_for_reconciliation!(fn ->
                 provision_tenant(astarte_config: [base_api_url: cluster.base_api_url])
               end)
    end

    test "fails with invalid tenant slug" do
      assert {:error, changeset} = provision_tenant(slug: "1-INVALID")
      assert errors_on(changeset)[:slug] != nil
    end

    test "fails with invalid tenant public key" do
      assert {:error, changeset} = provision_tenant(public_key: "invalid")
      assert errors_on(changeset)[:public_key] != nil
    end

    test "fails with invalid Astarte base API url" do
      assert {:error, changeset} = provision_tenant(astarte_config: [base_api_url: "invalid"])
      assert errors_on(changeset)[:astarte_config][:base_api_url] != nil
    end

    test "fails with invalid Astarte realm name" do
      assert {:error, changeset} = provision_tenant(astarte_config: [realm_name: "INVALID"])
      assert errors_on(changeset)[:astarte_config][:realm_name] != nil
    end

    test "fails with invalid Astarte realm private key" do
      assert {:error, changeset} =
               provision_tenant(astarte_config: [realm_private_key: "invalid"])

      assert errors_on(changeset)[:astarte_config][:realm_private_key] != nil
    end

    test "fails when providing an already existing tenant slug" do
      tenant = tenant_fixture()

      assert {:error, changeset} = provision_tenant(slug: tenant.slug)
      assert "has already been taken" in errors_on(changeset)[:slug]
    end

    test "fails when providing an already existing tenant name" do
      tenant = tenant_fixture()

      assert {:error, changeset} = provision_tenant(name: tenant.name)
      assert "has already been taken" in errors_on(changeset)[:name]
    end

    test "fails when providing an already existing realm name" do
      cluster = cluster_fixture()
      realm = realm_fixture(cluster)

      assert {:error, changeset} =
               [astarte_config: [base_api_url: cluster.base_api_url, realm_name: realm.name]]
               |> provision_tenant()

      assert "has already been taken" in errors_on(changeset)[:astarte_config][:realm_name]
    end
  end

  defp provision_tenant(opts) do
    {astarte_config, opts} = Keyword.pop(opts, :astarte_config, [])

    astarte_config =
      astarte_config
      |> Enum.into(%{
        base_api_url: unique_cluster_base_api_url(),
        realm_name: unique_realm_name(),
        realm_private_key: @valid_pem_private_key
      })

    attrs =
      opts
      |> Enum.into(%{
        name: unique_tenant_name(),
        slug: unique_tenant_slug(),
        public_key: @valid_pem_public_key,
        astarte_config: astarte_config
      })

    Provisioning.provision_tenant(attrs)
  end

  defp wait_for_reconciliation!(fun) do
    interface_count = Reconciler.Core.list_required_interfaces() |> length()
    trigger_count = Reconciler.Core.list_required_triggers("foo") |> length()

    test_process = self()

    Edgehog.Astarte.Realm.InterfacesMock
    |> expect(:get, interface_count, fn _client, _interface_name, _major ->
      {:error, api_error(status: 404)}
    end)
    |> expect(:create, interface_count, fn _client, _interface_map ->
      send(test_process, :reconciled)

      :ok
    end)

    Edgehog.Astarte.Realm.TriggersMock
    |> expect(:get, trigger_count, fn _client, _trigger_name ->
      {:error, api_error(status: 404)}
    end)
    |> expect(:create, trigger_count, fn _client, _trigger_map ->
      send(test_process, :reconciled)

      :ok
    end)

    result = fun.()

    1..(interface_count + trigger_count)
    |> Enum.each(fn _ -> assert_receive :reconciled end)

    result
  end

  defp api_error(opts) do
    status = Keyword.get(opts, :status, 500)
    message = Keyword.get(opts, :message, "Generic error")

    %APIError{
      status: status,
      response: %{"errors" => %{"detail" => message}}
    }
  end
end
