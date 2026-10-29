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

defmodule EdgehogWeb.Schema.Mutation.UpdateContainersResourcesTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers.ImageCredentials

  describe "updateApplication mutation" do
    @update_application_doc """
    mutation UpdateApplication($id: ID!, $input: UpdateApplicationInput!) {
      updateApplication(id: $id, input: $input) {
        result {
          id
          name
          description
        }
      }
    }
    """

    test "updates application name and description", %{tenant: tenant} do
      app = application_fixture(tenant: tenant, name: "Old App", description: "Old desc")
      app_id = AshGraphql.Resource.encode_relay_id(app)

      res =
        Absinthe.run!(@update_application_doc, EdgehogWeb.Schema,
          variables: %{
            "id" => app_id,
            "input" => %{"name" => "New App", "description" => "New desc"}
          },
          context: %{tenant: tenant}
        )

      assert %{
               data: %{
                 "updateApplication" => %{
                   "result" => %{
                     "id" => ^app_id,
                     "name" => "New App",
                     "description" => "New desc"
                   }
                 }
               }
             } = res
    end
  end

  describe "updateImageCredentials mutation" do
    @update_credentials_doc """
    mutation UpdateImageCredentials($id: ID!, $input: UpdateImageCredentialsInput!) {
      updateImageCredentials(id: $id, input: $input) {
        result {
          id
          label
          username
        }
      }
    }
    """

    test "updates image credentials label, username, and password", %{tenant: tenant} do
      creds =
        image_credentials_fixture(
          tenant: tenant,
          label: "old-creds",
          username: "old-user",
          password: "old-password"
        )

      creds_id = AshGraphql.Resource.encode_relay_id(creds)

      res =
        Absinthe.run!(@update_credentials_doc, EdgehogWeb.Schema,
          variables: %{
            "id" => creds_id,
            "input" => %{
              "label" => "new-creds",
              "username" => "new-user",
              "password" => "new-password"
            }
          },
          context: %{tenant: tenant}
        )

      assert %{
               data: %{
                 "updateImageCredentials" => %{
                   "result" => %{
                     "id" => ^creds_id,
                     "label" => "new-creds",
                     "username" => "new-user"
                   }
                 }
               }
             } = res

      updated = Ash.get!(ImageCredentials, creds.id, tenant: tenant)
      assert updated.password == "new-password"
    end
  end

  describe "updateVolume mutation" do
    @update_volume_doc """
    mutation UpdateVolume($id: ID!, $input: UpdateVolumeInput!) {
      updateVolume(id: $id, input: $input) {
        result {
          id
          label
          driver
          options
        }
      }
    }
    """

    test "updates plain volume and rejects duplicate plain label or deployed copy", %{
      tenant: tenant
    } do
      vol1 = volume_fixture(tenant: tenant, label: "vol-1", driver: "local")
      vol2 = volume_fixture(tenant: tenant, label: "vol-2", driver: "local")
      vol1_id = AshGraphql.Resource.encode_relay_id(vol1)

      res =
        Absinthe.run!(@update_volume_doc, EdgehogWeb.Schema,
          variables: %{
            "id" => vol1_id,
            "input" => %{
              "label" => "vol-1-renamed",
              "driver" => "nfs",
              "options" => Jason.encode!(%{"addr" => "10.0.0.1"})
            }
          },
          context: %{tenant: tenant}
        )

      assert %{
               data: %{
                 "updateVolume" => %{
                   "result" => %{
                     "id" => ^vol1_id,
                     "label" => "vol-1-renamed",
                     "driver" => "nfs",
                     "options" => "{\"addr\":\"10.0.0.1\"}"
                   }
                 }
               }
             } = res

      # Rejects duplicate plain volume label
      dup_res =
        Absinthe.run!(@update_volume_doc, EdgehogWeb.Schema,
          variables: %{
            "id" => vol1_id,
            "input" => %{"label" => vol2.label}
          },
          context: %{tenant: tenant}
        )

      assert %{data: %{"updateVolume" => nil}, errors: [_ | _]} = dup_res

      # Deploying a container with vol2 creates a deployed copy that cannot be updated via GraphQL
      container = container_fixture(tenant: tenant, volumes: [{vol2, "/mnt/v"}])
      release = release_fixture(tenant: tenant, container_ids: [container.id])
      device = device_fixture(tenant: tenant)

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id]
        |> deployment_fixture()
        |> Ash.load!([release: [containers: :volumes]], tenant: tenant)

      [deployed_container] = deployment.release.containers
      [deployed_volume] = deployed_container.volumes
      deployed_vol_id = AshGraphql.Resource.encode_relay_id(deployed_volume)

      deployed_res =
        Absinthe.run!(@update_volume_doc, EdgehogWeb.Schema,
          variables: %{
            "id" => deployed_vol_id,
            "input" => %{"driver" => "mutated"}
          },
          context: %{tenant: tenant}
        )

      assert %{data: %{"updateVolume" => nil}, errors: [_ | _]} = deployed_res
    end
  end

  describe "updateNetwork mutation" do
    @update_network_doc """
    mutation UpdateNetwork($id: ID!, $input: UpdateNetworkInput!) {
      updateNetwork(id: $id, input: $input) {
        result {
          id
          label
          driver
          internal
          enableIpv6
          options
        }
      }
    }
    """

    test "updates plain network and rejects duplicate plain label or deployed copy", %{
      tenant: tenant
    } do
      net1 = network_fixture(tenant: tenant, label: "net-1", driver: "bridge")
      net2 = network_fixture(tenant: tenant, label: "net-2", driver: "bridge")
      net1_id = AshGraphql.Resource.encode_relay_id(net1)

      res =
        Absinthe.run!(@update_network_doc, EdgehogWeb.Schema,
          variables: %{
            "id" => net1_id,
            "input" => %{
              "label" => "net-1-renamed",
              "driver" => "overlay",
              "internal" => true,
              "enableIpv6" => true,
              "options" => Jason.encode!(%{"mtu" => "1450"})
            }
          },
          context: %{tenant: tenant}
        )

      assert %{
               data: %{
                 "updateNetwork" => %{
                   "result" => %{
                     "id" => ^net1_id,
                     "label" => "net-1-renamed",
                     "driver" => "overlay",
                     "internal" => true,
                     "enableIpv6" => true,
                     "options" => "{\"mtu\":\"1450\"}"
                   }
                 }
               }
             } = res

      # Rejects duplicate plain network label
      dup_res =
        Absinthe.run!(@update_network_doc, EdgehogWeb.Schema,
          variables: %{
            "id" => net1_id,
            "input" => %{"label" => net2.label}
          },
          context: %{tenant: tenant}
        )

      assert %{data: %{"updateNetwork" => nil}, errors: [_ | _]} = dup_res

      # Deploying a container with net2 creates a deployed copy that cannot be updated via GraphQL
      container = container_fixture(tenant: tenant, networks: [net2])
      release = release_fixture(tenant: tenant, container_ids: [container.id])
      device = device_fixture(tenant: tenant)

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id]
        |> deployment_fixture()
        |> Ash.load!([release: [containers: :networks]], tenant: tenant)

      [deployed_container] = deployment.release.containers
      [deployed_network] = deployed_container.networks
      deployed_net_id = AshGraphql.Resource.encode_relay_id(deployed_network)

      deployed_res =
        Absinthe.run!(@update_network_doc, EdgehogWeb.Schema,
          variables: %{
            "id" => deployed_net_id,
            "input" => %{"driver" => "mutated"}
          },
          context: %{tenant: tenant}
        )

      assert %{data: %{"updateNetwork" => nil}, errors: [_ | _]} = deployed_res
    end
  end
end
