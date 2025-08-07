#
# This file is part of Edgehog.
#
# Copyright 2025 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeleteReleaseTest do
  @moduledoc false
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Ash.Error.Invalid

  describe "deleteRelease mutation" do
    setup %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      release = release_fixture(application_id: application.id, containers: 2, tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(release)

      %{application: application, release: release, id: id}
    end

    test "delete release with valid data", %{
      tenant: tenant,
      release: release,
      id: id
    } do
      delete_release =
        [tenant: tenant, id: id]
        |> delete_release_mutation()
        |> extract_result!()

      assert delete_release["version"] == release.version
    end

    test "delete release fails with invalid data", %{tenant: tenant} do
      id = non_existing_release_id(tenant)

      result = delete_release_mutation(tenant: tenant, id: id)

      assert %{errors: [%{code: "not_found"}]} = result
    end

    test "delete release with active deployments should fail", %{
      tenant: tenant,
      release: release,
      id: id
    } do
      # Create a device and deploy the release
      device = device_fixture(tenant: tenant)

      _deployment =
        deployment_fixture(release_id: release.id, device_id: device.id, tenant: tenant)

      result = delete_release_mutation(tenant: tenant, id: id)

      assert %{errors: [%{message: message}]} = result
      assert message =~ "Cannot delete release with active deployments"
    end

    test "delete release with stopped deployments should succeed by auto-deleting deployments", %{
      tenant: tenant,
      release: release,
      id: id
    } do
      # Create a device and deploy the release
      device = device_fixture(tenant: tenant)

      deployment =
        deployment_fixture(release_id: release.id, device_id: device.id, tenant: tenant)

      # Update the deployment to stopped state
      deployment = Ash.Changeset.for_update(deployment, :mark_as_stopped)
      _updated_deployment = Ash.update!(deployment, tenant: tenant)

      # Deletion should now succeed because stopped deployments are auto-deleted
      delete_release =
        [tenant: tenant, id: id]
        |> delete_release_mutation()
        |> extract_result!()

      assert delete_release["version"] == release.version
    end

    test "delete release with stopped deployments should succeed after deleting deployments", %{
      tenant: tenant,
      release: release,
      id: id
    } do
      # Create a device and deploy the release
      device = device_fixture(tenant: tenant)

      deployment =
        deployment_fixture(release_id: release.id, device_id: device.id, tenant: tenant)

      # Update the deployment to stopped state
      deployment = Ash.Changeset.for_update(deployment, :mark_as_stopped)
      updated_deployment = Ash.update!(deployment, tenant: tenant)

      # Delete the stopped deployment first (this should be allowed)
      :ok = Ash.destroy!(updated_deployment, tenant: tenant)

      # Now delete should succeed since no deployments reference the release
      delete_release =
        [tenant: tenant, id: id]
        |> delete_release_mutation()
        |> extract_result!()

      assert delete_release["version"] == release.version
    end

    test "delete release cleans up containers and images when not shared with other releases", %{
      tenant: tenant,
      release: release,
      id: id
    } do
      # Load release with containers to check they exist before deletion
      release_with_containers = Ash.load!(release, [:containers], tenant: tenant)
      containers_before = release_with_containers.containers

      # Verify containers exist
      assert length(containers_before) > 0

      # Get the image IDs before deletion to verify cleanup
      image_ids =
        containers_before
        |> Enum.map(& &1.image_id)
        |> Enum.uniq()

      # Delete the release
      delete_release_mutation(tenant: tenant, id: id)

      # Verify containers are deleted
      for container <- containers_before do
        assert_raise Invalid, fn ->
          Ash.get!(Edgehog.Containers.Container, container.id, tenant: tenant)
        end
      end

      # Verify images are deleted (since they're not shared with other containers)
      for image_id <- image_ids do
        assert_raise Invalid, fn ->
          Ash.get!(Edgehog.Containers.Image, image_id, tenant: tenant)
        end
      end
    end
  end

  @delete_release_mutation """
  mutation DeleteRelease($id: ID!) {
    deleteRelease(id: $id) {
      result {
        id
        version
      }
    }
  }
  """

  defp delete_release_mutation(opts) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}

    Absinthe.run!(@delete_release_mutation, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant}
    )
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteRelease" => %{
                 "result" => release
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert release != nil

    release
  end

  defp non_existing_release_id(tenant) do
    fixture = release_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, tenant: tenant)

    id
  end
end
