#
# This file is part of Edgehog.
#
# Copyright 2023 - 2026 SECO Mind Srl
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

defmodule EdgehogWeb.Schema.Mutation.DeleteBaseImageTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.BaseImagesFixtures

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.BaseImages.StorageMock
  alias Edgehog.CampaignsFixtures

  require Ash.Query

  describe "deleteBaseImage mutation" do
    setup %{tenant: tenant} do
      base_image =
        base_image_fixture(tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(base_image)

      %{base_image: base_image, id: id}
    end

    test "deletes existing base image", %{tenant: tenant, id: id, base_image: fixture} do
      expect(StorageMock, :delete, fn _ -> :ok end)

      base_image =
        [tenant: tenant, id: id]
        |> delete_base_image_mutation()
        |> extract_result!()

      assert base_image["version"] == fixture.version

      refute BaseImage
             |> Ash.Query.filter(id == ^fixture.id)
             |> Ash.Query.set_tenant(tenant)
             |> Ash.exists?()
    end

    test "tries to delete the file, but ignores failure", %{tenant: tenant} do
      file_url = "https://example.com/ota.bin"

      fixture = base_image_fixture(tenant: tenant, url: file_url)

      id = AshGraphql.Resource.encode_relay_id(fixture)

      expect(StorageMock, :delete, fn _ -> {:error, :cannot_delete} end)

      %{"id" => ^id} =
        [tenant: tenant, id: id]
        |> delete_base_image_mutation()
        |> extract_result!()
    end

    test "fails with non-existing base image", %{tenant: tenant, base_image: base_image, id: id} do
      :ok = Ash.destroy!(base_image, action: :destroy_fixture)

      result = delete_base_image_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "could not be found"} = extract_error!(result)
    end

    test "fails if the image is used in an Update Campaign", %{
      tenant: tenant,
      base_image: base_image,
      id: id
    } do
      CampaignsFixtures.campaign_fixture(
        tenant: tenant,
        base_image_id: base_image.id,
        mechanism_type: :firmware_upgrade
      )

      result = delete_base_image_mutation(tenant: tenant, id: id)

      assert %{fields: [:id], message: "Base image is currently in use by at least one campaign"} =
               extract_error!(result)
    end
  end

  defp delete_base_image_mutation(opts) do
    default_document = """
    mutation DeleteBaseImage($id: ID!) {
      deleteBaseImage(id: $id) {
        result {
          id
          version
          url
          startingVersionRequirement
        }
      }
    }
    """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    {id, opts} = Keyword.pop!(opts, :id)

    document = Keyword.get(opts, :document, default_document)
    variables = %{"id" => id}
    context = %{tenant: tenant}

    Absinthe.run!(document, EdgehogWeb.Schema, variables: variables, context: context)
  end

  defp extract_error!(result) do
    assert %{
             data: %{"deleteBaseImage" => nil},
             errors: [error]
           } = result

    error
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteBaseImage" => %{
                 "result" => base_image
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert base_image

    base_image
  end
end
