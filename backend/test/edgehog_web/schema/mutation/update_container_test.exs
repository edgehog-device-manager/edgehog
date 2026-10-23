#
# This file is part of Edgehog.
#
# Copyright 2024 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.UpdateContainerTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Edgehog.Containers
  alias Edgehog.Containers.Image

  describe "updateContainer mutation" do
    test "successfully updates the container name", %{tenant: tenant} do
      container = container_fixture(tenant: tenant, name: "old-name")
      container_id = AshGraphql.Resource.encode_relay_id(container)
      new_name = "new-shiny-name"

      document = """
      mutation UpdateContainer($id: ID!, $input: UpdateContainerInput!) {
        updateContainer(id: $id, input: $input) {
          result {
            id
            name
          }
        }
      }
      """

      input = %{"name" => new_name}

      response =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => container_id, "input" => input},
          context: %{tenant: tenant}
        )

      result = extract_result!(response)

      assert result["name"] == new_name

      db_container = Containers.fetch_container!(container.id, tenant: tenant)
      assert db_container.name == new_name
    end

    test "updates container attributes and relations while preserving same image or GCing replaced image",
         %{tenant: tenant} do
      vol1 = volume_fixture(tenant: tenant, label: "vol-1")
      vol2 = volume_fixture(tenant: tenant, label: "vol-2")
      vol3 = volume_fixture(tenant: tenant, label: "vol-3")

      net1 = network_fixture(tenant: tenant, label: "net-1")
      net2 = network_fixture(tenant: tenant, label: "net-2")

      image1 = image_fixture(tenant: tenant, reference: "alpine:3.18")
      dm1 = device_mapping_fixture(tenant: tenant, path_on_host: "/dev/ttyS0")
      dr1 = device_request_fixture(tenant: tenant, driver: "nvidia", count: 1)

      container =
        container_fixture(
          tenant: tenant,
          name: "my-container",
          image: image1,
          volumes: [{vol1, "/mnt/v1"}, {vol2, "/mnt/v2"}],
          networks: [net1],
          file_mounts: [
            %{mountpoint: "/etc/a.conf", required: true, file_mode: 420},
            %{mountpoint: "/etc/b.conf", required: false}
          ],
          device_mappings: [dm1],
          device_requests: [dr1]
        )

      container_id = AshGraphql.Resource.encode_relay_id(container)
      vol1_id = AshGraphql.Resource.encode_relay_id(vol1)
      vol3_id = AshGraphql.Resource.encode_relay_id(vol3)
      net2_id = AshGraphql.Resource.encode_relay_id(net2)
      image1_relay_id = AshGraphql.Resource.encode_relay_id(image1)

      document = """
      mutation UpdateContainer($id: ID!, $input: UpdateContainerInput!) {
        updateContainer(id: $id, input: $input) {
          result {
            id
            name
            hostname
            restartPolicy
            privileged
            image {
              id
              reference
            }
            containerVolumes {
              edges {
                node {
                  target
                  volume {
                    id
                    label
                  }
                }
              }
            }
            networks {
              edges {
                node {
                  id
                  label
                }
              }
            }
            fileMounts {
              edges {
                node {
                  mountpoint
                  required
                  fileMode
                }
              }
            }
            deviceMappings {
              edges {
                node {
                  pathOnHost
                  pathInContainer
                  cgroupPermissions
                }
              }
            }
            deviceRequests {
              edges {
                node {
                  driver
                  count
                }
              }
            }
          }
        }
      }
      """

      res1 =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{
            "id" => container_id,
            "input" => %{
              "name" => "my-container-updated",
              "hostname" => "updated-host",
              "restartPolicy" => "ALWAYS",
              "privileged" => true,
              "image" => %{"reference" => "alpine:3.18"},
              "volumes" => [
                %{"id" => vol1_id, "target" => "/mnt/v1-new"},
                %{"id" => vol3_id, "target" => "/mnt/v3"}
              ],
              "networks" => [
                %{"id" => net2_id}
              ],
              "fileMounts" => [
                %{"mountpoint" => "/etc/a.conf", "required" => false, "fileMode" => 511},
                %{"mountpoint" => "/etc/c.conf", "required" => true}
              ],
              "deviceMappings" => [
                %{
                  "pathOnHost" => "/dev/video0",
                  "pathInContainer" => "/dev/video0",
                  "cgroupPermissions" => "rwm"
                }
              ],
              "deviceRequests" => [
                %{"driver" => "amd", "count" => 2}
              ]
            }
          },
          context: %{tenant: tenant}
        )

      result = extract_result!(res1)

      assert result["name"] == "my-container-updated"
      assert result["hostname"] == "updated-host"
      assert result["restartPolicy"] == "always"
      assert result["privileged"] == true
      assert result["image"] == %{"id" => image1_relay_id, "reference" => "alpine:3.18"}

      # Verify image1 was NOT destroyed
      assert {:ok, _} = Ash.get(Image, image1.id, tenant: tenant)

      cv_targets =
        result["containerVolumes"]["edges"]
        |> Enum.map(fn %{"node" => node} -> {node["volume"]["id"], node["target"]} end)
        |> MapSet.new()

      assert cv_targets == MapSet.new([{vol1_id, "/mnt/v1-new"}, {vol3_id, "/mnt/v3"}])

      fm_map =
        Map.new(result["fileMounts"]["edges"], fn %{"node" => node} ->
          {node["mountpoint"], {node["required"], node["fileMode"]}}
        end)

      assert fm_map == %{
               "/etc/a.conf" => {false, 511},
               "/etc/c.conf" => {true, nil}
             }

      # Updating container image to a new reference garbage-collects the old dangling image
      res2 =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{
            "id" => container_id,
            "input" => %{"image" => %{"reference" => "alpine:3.19"}}
          },
          context: %{tenant: tenant}
        )

      result2 = extract_result!(res2)
      assert result2["image"]["reference"] == "alpine:3.19"
      assert {:error, _} = Ash.get(Image, image1.id, tenant: tenant)
    end

    test "rejects updating a deployed container copy", %{tenant: tenant} do
      container = container_fixture(tenant: tenant, name: "plain-container")
      release = release_fixture(tenant: tenant, container_ids: [container.id])
      device = device_fixture(tenant: tenant)

      deployment =
        [tenant: tenant, device_id: device.id, release_id: release.id]
        |> deployment_fixture()
        |> Ash.load!([release: :containers], tenant: tenant)

      [deployed_container] = deployment.release.containers
      deployed_container_id = AshGraphql.Resource.encode_relay_id(deployed_container)

      document = """
      mutation UpdateContainer($id: ID!, $input: UpdateContainerInput!) {
        updateContainer(id: $id, input: $input) {
          result { id }
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => deployed_container_id, "input" => %{"name" => "mutated"}},
          context: %{tenant: tenant}
        )

      assert %{data: %{"updateContainer" => nil}, errors: [_ | _]} = result
    end

    test "returns an error when the container does not exist", %{tenant: tenant} do
      bad_uuid = Ecto.UUID.generate()
      bad_id = Base.encode64("Container:#{bad_uuid}")

      document = """
      mutation UpdateContainer($id: ID!, $input: UpdateContainerInput!) {
        updateContainer(id: $id, input: $input) {
          result { id }
        }
      }
      """

      result =
        Absinthe.run!(document, EdgehogWeb.Schema,
          variables: %{"id" => bad_id, "input" => %{"name" => "wont-work"}},
          context: %{tenant: tenant}
        )

      assert %{errors: [%{code: "invalid_primary_key"}]} = result
    end
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "updateContainer" => %{
                 "result" => container
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert container

    container
  end
end
