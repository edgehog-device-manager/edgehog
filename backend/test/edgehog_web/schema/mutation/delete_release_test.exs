#
# This file is part of Edgehog.
#
# Copyright 2025-2026 SECO Mind Srl
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
  alias Edgehog.Containers.Container
  alias Edgehog.Containers.Image
  alias Edgehog.Containers.Release
  alias Edgehog.Containers.ReleaseContainers

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

      deployment =
        deployment_fixture(release_id: release.id, device_id: device.id, tenant: tenant)

      deployed_release = Ash.get!(Release, deployment.release_id, tenant: tenant)
      deployed_release_id = AshGraphql.Resource.encode_relay_id(deployed_release)

      # Try to delete the deployed release copy
      error =
        [tenant: tenant, id: deployed_release_id]
        |> delete_release()
        |> extract_error!()

      assert is_binary(error.message)

      # Verify deployed release still exists and wasn't deleted
      assert {:ok, _release} = Ash.get(Release, deployed_release.id, tenant: tenant)

      # The original plain release can still be deleted without affecting the deployment
      plain_release_id = AshGraphql.Resource.encode_relay_id(release)

      deleted_plain =
        [tenant: tenant, id: plain_release_id]
        |> delete_release()
        |> extract_result!()

      assert deleted_plain["id"] == plain_release_id
      assert {:error, %Invalid{}} = Ash.get(Release, release.id, tenant: tenant)
      assert {:ok, _release} = Ash.get(Release, deployed_release.id, tenant: tenant)
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

    Absinthe.run!(document, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant, actor: %{}}
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

    refute :errors in Map.keys(result)
    assert release

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
