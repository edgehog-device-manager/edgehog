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

defmodule Edgehog.StorageTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  alias Edgehog.BaseImages.BaseImage

  @moduletag :integration_storage

  setup do
    # Do not mock the storage for integration
    Mox.stub_with(Edgehog.BaseImages.StorageMock, Edgehog.BaseImages.BucketStorage)
    Mox.stub_with(Edgehog.Assets.SystemModelPictureMock, Edgehog.Assets.SystemModelPicture)
    Mox.stub_with(Edgehog.OSManagement.EphemeralImageMock, Edgehog.OSManagement.EphemeralImage)

    :ok
  end

  test "Base Images can be uploaded, read and deleted" do
    tenant = Edgehog.TenantsFixtures.tenant_fixture()

    base_image_collection =
      Edgehog.BaseImagesFixtures.base_image_collection_fixture(tenant: tenant)

    file = temporary_file_fixture()
    version = "0.0.1"

    base_image =
      Ash.create!(
        BaseImage,
        %{version: version, base_image_collection_id: base_image_collection.id, file: file},
        tenant: tenant
      )

    result =
      HTTPoison.request(%HTTPoison.Request{method: :get, url: base_image.url})

    assert {:ok, %{status_code: 200, body: result_body}} = result
    assert File.read!(file.path) == result_body

    Ash.destroy!(base_image)

    result =
      HTTPoison.request(%HTTPoison.Request{method: :get, url: base_image.url})

    assert {:ok, %{status_code: 404}} = result
  end

  test "System Model Picture can be uploaded, read and deleted" do
    tenant = Edgehog.TenantsFixtures.tenant_fixture()
    filename = "example.png"
    expected_content_type = "image/png"
    file = temporary_file_fixture(file_name: filename)

    system_model =
      Edgehog.DevicesFixtures.system_model_fixture(picture_file: file, tenant: tenant)

    result =
      HTTPoison.request(%HTTPoison.Request{method: :get, url: system_model.picture_url})

    assert {:ok, %{status_code: 200, body: result_body, headers: headers}} = result

    {_header, content_type} =
      Enum.find(headers, fn {key, _value} -> String.downcase(key) == "content-type" end)

    assert content_type == expected_content_type
    assert File.read!(file.path) == result_body

    Ash.destroy!(system_model)

    result =
      HTTPoison.request(%HTTPoison.Request{method: :get, url: system_model.picture_url})

    assert {:ok, %{status_code: 404}} = result
  end

  test "Ephemeral Images can be uploaded and read" do
    tenant = Edgehog.TenantsFixtures.tenant_fixture()
    file = temporary_file_fixture()
    device_id = [tenant: tenant] |> Edgehog.DevicesFixtures.device_fixture() |> Map.fetch!(:id)

    Mox.stub(Edgehog.Astarte.Device.OTARequestV1Mock, :update, fn _, _, _, _ -> :ok end)

    ota_operation =
      Edgehog.OSManagement.OTAOperation
      |> Ash.Changeset.for_create(:manual, [device_id: device_id, base_image_file: file], tenant: tenant)
      |> Ash.create!()

    result =
      HTTPoison.request(%HTTPoison.Request{method: :get, url: ota_operation.base_image_url})

    assert {:ok, %{status_code: 200, body: result_body}} = result
    assert File.read!(file.path) == result_body
  end

  def temporary_file_fixture(opts \\ []) do
    file_name = Keyword.get(opts, :file_name, "example.bin")
    contents = Keyword.get(opts, :contents, "example")
    content_type = Keyword.get(opts, :content_type)

    temp_file = Plug.Upload.random_file!(file_name)
    File.write!(temp_file, contents)

    %Plug.Upload{path: temp_file, filename: file_name, content_type: content_type}
  end
end
