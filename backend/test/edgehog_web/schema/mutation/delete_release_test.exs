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

  import Ash.Expr
  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  alias Ash.Error.Invalid
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.ReleaseContainers

  require Ash.Query

  describe "deleteRelease mutation" do
    test "deletes release without deployments", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      release = release_fixture(application_id: application.id, tenant: tenant)

      release_id = AshGraphql.Resource.encode_relay_id(release)

      # Delete the release
      deleted_release =
        [tenant: tenant, id: release_id]
        |> delete_release()
        |> extract_result!()

      assert deleted_release["id"] == release_id

      # Verify release is actually deleted
      assert {:error, %Invalid{}} =
               Ash.get(Release, release.id, tenant: tenant)
    end

    test "fails to delete release with active deployments", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      release = release_fixture(application_id: application.id, tenant: tenant)
      device = device_fixture(tenant: tenant)
      deployment_fixture(release_id: release.id, device_id: device.id, tenant: tenant)

      release_id = AshGraphql.Resource.encode_relay_id(release)

      # Try to delete the release
      error =
        [tenant: tenant, id: release_id]
        |> delete_release()
        |> extract_error!()

      assert is_binary(error.message)

      # Verify release still exists and wasn't deleted
      assert {:ok, _release} = Ash.get(Release, release.id, tenant: tenant)
    end

    test "cleans up dangling containers and images after release deletion", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      release = release_fixture(application_id: application.id, tenant: tenant, containers: 2)

      release_id = AshGraphql.Resource.encode_relay_id(release)

      # Get the containers to track them
      {:ok, release_with_containers} = Ash.load(release, :containers)
      containers = release_with_containers.containers
      container_ids = Enum.map(containers, & &1.id)
      image_ids = Enum.map(containers, & &1.image_id)

      # Delete the release
      deleted_release =
        [tenant: tenant, id: release_id]
        |> delete_release()
        |> extract_result!()

      assert deleted_release["id"] == release_id

      # Verify containers are cleaned up
      for container_id <- container_ids do
        assert {:error, %Invalid{}} =
                 Ash.get(Container, container_id, tenant: tenant)
      end

      # Verify images are cleaned up
      for image_id <- image_ids do
        assert {:error, %Invalid{}} =
                 Ash.get(Image, image_id, tenant: tenant)
      end

      # Verify containers are no longer associated with the deleted release
      for container_id <- container_ids do
        release_containers =
          ReleaseContainers
          |> Ash.Query.filter(expr(container_id == ^container_id))
          |> Ash.read!(tenant: tenant)

        # Should have no release associations now
        assert Enum.empty?(release_containers)
      end
    end

    test "does not delete containers referenced by other releases", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      shared_container = container_fixture(tenant: tenant)

      release1 = release_fixture(application_id: application.id, tenant: tenant)
      release2 = release_fixture(application_id: application.id, tenant: tenant)

      # Manually associate the shared container with both releases
      Ash.create!(
        ReleaseContainers,
        %{release_id: release1.id, container_id: shared_container.id},
        tenant: tenant
      )

      Ash.create!(
        ReleaseContainers,
        %{release_id: release2.id, container_id: shared_container.id},
        tenant: tenant
      )

      release1_id = AshGraphql.Resource.encode_relay_id(release1)

      # Delete the first release
      deleted_release =
        [tenant: tenant, id: release1_id]
        |> delete_release()
        |> extract_result!()

      assert deleted_release["id"] == release1_id

      # Verify the shared container still exists (not dangling)
      assert Ash.get(Container, shared_container.id, tenant: tenant)
      assert Ash.get(Image, shared_container.image_id, tenant: tenant)
    end

    test "fails with non-existing release", %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      temp_release = release_fixture(application_id: application.id, tenant: tenant)

      # Create a fake ID based on the real release structure but with generated UUID
      fake_release = %{temp_release | id: Ash.UUID.generate()}
      non_existing_id = AshGraphql.Resource.encode_relay_id(fake_release)

      error =
        [tenant: tenant, id: non_existing_id]
        |> delete_release()
        |> extract_error!()

      assert is_binary(error.message)
    end
  end

  @default_document """
  mutation DeleteRelease($id: ID!) {
    deleteRelease(id: $id) {
      result {
        id
        version
      }
    }
  }
  """

  defp delete_release(opts) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    variables = %{"id" => id}
    document = Keyword.get(opts, :document, @default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: %{tenant: tenant})
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteRelease" => %{
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
             data: %{
               "deleteRelease" => nil
             },
             errors: [error]
           } = result

    error
  end
end
