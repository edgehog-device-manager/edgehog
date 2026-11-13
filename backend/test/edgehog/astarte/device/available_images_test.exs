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

defmodule Edgehog.Astarte.Device.AvailableImagesTest do
  use Edgehog.DataCase, async: true

  import Edgehog.AstarteFixtures
  import Edgehog.DevicesFixtures
  import Edgehog.TenantsFixtures
  import Tesla.Mock

  alias Astarte.Client.AppEngine
  alias Edgehog.Astarte.Device.AvailableImages
  alias Edgehog.Astarte.Device.AvailableImages.ImageStatus

  setup do
    tenant = tenant_fixture()
    cluster = cluster_fixture()
    realm = realm_fixture(cluster_id: cluster.id, tenant: tenant)
    device = device_fixture(realm_id: realm.id, tenant: tenant)

    {:ok, appengine_client} =
      AppEngine.new(cluster.base_api_url, realm.name, private_key: realm.private_key)

    {:ok, device: device, appengine_client: appengine_client}
  end

  test "get/2 correctly parses available images", %{
    device: device,
    appengine_client: appengine_client
  } do
    response = %{
      "data" => %{
        "uniqueid1" => %{
          "pulled" => true,
          "status" => "Pulled",
          "imageId" => "sha256:abc123",
          "repoTags" => ["nginx:latest"],
          "repoDigests" => ["nginx@sha256:abc123"],
          "size" => "3000000000"
        },
        "uniqueid2" => %{
          "pulled" => false
        }
      }
    }

    mock(fn
      %{method: :get, url: _api_url} ->
        json(response)
    end)

    assert {:ok, images} = AvailableImages.get(appengine_client, device.device_id)

    assert Enum.sort_by(images, & &1.id) == [
             %ImageStatus{
               id: "uniqueid1",
               pulled: true,
               status: "Pulled",
               image_id: "sha256:abc123",
               repo_tags: ["nginx:latest"],
               repo_digests: ["nginx@sha256:abc123"],
               size: 3_000_000_000
             },
             %ImageStatus{
               id: "uniqueid2",
               pulled: false
             }
           ]
  end
end
