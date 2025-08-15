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

defmodule EdgehogWeb.Schema.Mutation.DeleteApplicationTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.DevicesFixtures

  describe "deleteApplication mutation" do
    setup %{tenant: tenant} do
      application = application_fixture(tenant: tenant)
      _release = release_fixture(application_id: application.id, containers: 2, tenant: tenant)

      id = AshGraphql.Resource.encode_relay_id(application)

      %{application: application, id: id}
    end

    test "delete application with valid data", %{
      tenant: tenant,
      application: application,
      id: id
    } do
      delete_application =
        [tenant: tenant, id: id]
        |> delete_application_mutation()
        |> extract_result!()

      assert delete_application["description"] == application.description
    end

    test "delete application fails with invalid data", %{tenant: tenant} do
      id = non_existing_application_id(tenant)

      result = delete_application_mutation(tenant: tenant, id: id)

      assert %{errors: [%{code: "not_found"}]} = result
    end
  end

  test "delete application fails when release cant be deleted", %{tenant: tenant} do
    application = application_fixture(tenant: tenant)
    release = release_fixture(application_id: application.id, tenant: tenant)
    device = device_fixture(tenant: tenant)
    deployment_fixture(release_id: release.id, device_id: device.id, tenant: tenant)

    app_id = AshGraphql.Resource.encode_relay_id(application)

    error =
      [tenant: tenant, id: app_id]
      |> delete_application_mutation()
      |> extract_error!()

    assert error.message ==
             "Cannot delete application: the following releases cannot be destroyed: #{release.version}"
  end

  @delete_application_mutation """
  mutation DeleteApplication($id: ID!) {
    deleteApplication(id: $id) {
      result {
        id
        description
      }
    }
  }
  """

  defp delete_application_mutation(opts) do
    {tenant, opts} = Keyword.pop!(opts, :tenant)
    id = Keyword.fetch!(opts, :id)

    variables = %{"id" => id}

    Absinthe.run!(@delete_application_mutation, EdgehogWeb.Schema,
      variables: variables,
      context: %{tenant: tenant}
    )
  end

  defp extract_result!(result) do
    assert %{
             data: %{
               "deleteApplication" => %{
                 "result" => application
               }
             }
           } = result

    refute Map.get(result, :errors)

    assert application != nil

    application
  end

  defp extract_error!(result) do
    assert %{
             data: %{
               "deleteApplication" => nil
             },
             errors: [error]
           } = result

    error
  end

  defp non_existing_application_id(tenant) do
    fixture = application_fixture(tenant: tenant)
    id = AshGraphql.Resource.encode_relay_id(fixture)

    :ok = Ash.destroy!(fixture, tenant: tenant)

    id
  end
end
