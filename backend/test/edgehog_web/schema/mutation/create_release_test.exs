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

defmodule EdgehogWeb.Schema.Mutation.CreateReleaseTest do
  @moduledoc false

  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures

  describe "createRelease mutation" do
    test "create release with valid application and parameters", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)

      network = network_fixture(tenant: tenant)
      existing_network_id = AshGraphql.Resource.encode_relay_id(network)

      container_hostname = "new_container"
      network_driver = "custom_driver"

      containers = [
        %{"hostname" => container_hostname, "image" => %{"reference" => "alpine:latest"}}
      ]

      networks = [%{"driver" => network_driver}, %{"id" => existing_network_id}]

      version = "0.0.1"

      release =
        [
          tenant: tenant,
          application_id: application_id,
          version: version,
          containers: containers,
          networks: networks
        ]
        |> create_release()
        |> extract_result!()

      assert release["version"] == version
      assert release["application"]["id"] == application_id

      {:ok, %{id: release_id}} = AshGraphql.Resource.decode_relay_id(release["id"])

      release =
        Ash.get!(Edgehog.Containers.Release, release_id,
          tenant: tenant,
          load: [:containers, :networks]
        )

      assert Enum.find(release.containers, &(&1.hostname == container_hostname))
      assert Enum.find(release.networks, &(&1.driver == network_driver))
      assert Enum.find(release.networks, &(&1.id == network.id))
    end

    test "create release with invalid application throws error", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      application_id = AshGraphql.Resource.encode_relay_id(application)
      :ok = Ash.destroy!(application, tenant: tenant)

      version = "0.0.1"

      error =
        [tenant: tenant, application_id: application_id, version: version]
        |> create_release()
        |> extract_error!()

      assert [:application_id] = error.fields
      assert "does not exist" == error.message
    end

    test "create release with already available version throws error version already taken", %{
      tenant: tenant
    } do
      version = "0.0.1"
      release = [tenant: tenant, version: version] |> release_fixture() |> Ash.load!(:application)
      application_id = AshGraphql.Resource.encode_relay_id(release.application)

      error =
        [tenant: tenant, application_id: application_id, version: version]
        |> create_release()
        |> extract_error!()

      assert [:version] = error.fields
      assert "has already been taken" == error.message
    end
  end

  def create_release(opts) do
    default_document = """
    mutation CreateRelease($input: CreateReleaseInput!) {
      createRelease(input: $input) {
        result {
          id
          version
          application {
            id
          }
        }
      }
    }
    """

    tenant = Keyword.fetch!(opts, :tenant)

    default_input = %{
      "version" => unique_release_version(),
      "containers" => []
    }

    input =
      opts
      |> Keyword.take([:application_id, :version, :containers, :networks])
      |> Enum.into(default_input, fn {key, value} -> {Atom.to_string(key), value} end)

    variables = %{"input" => input}

    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    assert %{
             data: %{
               "createRelease" => %{
                 "result" => release
               }
             }
           } = result

    refute :errors in Map.keys(result)
    assert release != nil

    release
  end

  defp extract_error!(result) do
    assert %{
             data: %{"createRelease" => nil},
             errors: [error]
           } = result

    error
  end
end
