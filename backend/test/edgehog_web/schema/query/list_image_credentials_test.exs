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

defmodule EdgehogWeb.Schema.Query.ListImageCredentialsTest do
  use EdgehogWeb.GraphqlCase, async: true

  import Edgehog.ImageCredentialsFixtures

  describe "image credentials queries" do
    test "no image credentials at startup", %{tenant: tenant} do
      data = [tenant: tenant] |> list_image_credentials() |> extract_result!()
      assert %{"listImageCredentials" => []} = data
    end

    test "returns all image credentials when present", %{tenant: tenant} do
      fixture1 = image_credentials_fixture(tenant: tenant)
      fixture2 = image_credentials_fixture(tenant: tenant)
      fixture3 = image_credentials_fixture(tenant: tenant)

      data = [tenant: tenant] |> list_image_credentials() |> extract_result!()

      assert %{"listImageCredentials" => image_credentials} = data
      assert length(image_credentials) == 3

      names = Enum.map(image_credentials, & &1["name"])

      for fix <- [fixture1, fixture2, fixture3] do
        assert fix.name in names
      end
    end
  end

  defp list_image_credentials(opts) do
    default_document =
      """
      query {
        listImageCredentials {
          name
          username
        }
      }
      """

    {tenant, opts} = Keyword.pop!(opts, :tenant)
    document = Keyword.get(opts, :document, default_document)

    Absinthe.run!(document, EdgehogWeb.Schema, context: %{tenant: tenant})
  end

  def extract_result!(result) do
    refute :errors in Map.keys(result)
    assert %{data: data} = result
    assert data != nil

    data
  end
end
