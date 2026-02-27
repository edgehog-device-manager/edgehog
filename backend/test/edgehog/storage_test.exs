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

defmodule Edgehog.StorageTest do
  @moduledoc false
  use Edgehog.DataCase, async: true

  alias Edgehog.BaseImages.BaseImage
  alias Edgehog.Files.File
  alias Edgehog.Files.FileDownloadRequest

  @moduletag :integration_storage

  setup do
    tenant = Edgehog.TenantsFixtures.tenant_fixture()

    {:ok, tenant: tenant}
  end

  describe "Backend Storage Integration test" do
    setup do
      # Do not mock the storage for integration
      Mox.stub_with(Edgehog.BaseImages.StorageMock, Edgehog.BaseImages.BucketStorage)
      Mox.stub_with(Edgehog.Assets.SystemModelPictureMock, Edgehog.Assets.SystemModelPicture)
      Mox.stub_with(Edgehog.OSManagement.EphemeralImageMock, Edgehog.OSManagement.EphemeralImage)

      :ok
    end

    test "Base Images can be uploaded, read and deleted", %{tenant: tenant} do
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
      assert Elixir.File.read!(file.path) == result_body

      Ash.destroy!(base_image)

      result =
        HTTPoison.request(%HTTPoison.Request{method: :get, url: base_image.url})

      assert {:ok, %{status_code: 404}} = result
    end

    test "System Model Picture can be uploaded, read and deleted", %{tenant: tenant} do
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
      assert Elixir.File.read!(file.path) == result_body

      Ash.destroy!(system_model)

      result =
        HTTPoison.request(%HTTPoison.Request{method: :get, url: system_model.picture_url})

      assert {:ok, %{status_code: 404}} = result
    end

    test "Ephemeral Images can be uploaded and read", %{tenant: tenant} do
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
      assert Elixir.File.read!(file.path) == result_body
    end
  end

  describe "File presigned URL" do
    test "create_presigned_url returns presigned URLs containing the correct file path", %{
      tenant: tenant
    } do
      filename = "My File 1"

      repository = Edgehog.FilesFixtures.repository_fixture(tenant: tenant)

      result =
        File
        |> Ash.ActionInput.for_action(:create_presigned_url, %{
          filename: filename,
          repository_id: repository.id
        })
        |> Ash.run_action!(tenant: tenant)

      assert is_map(result)
      assert Map.has_key?(result, :get_url)
      assert Map.has_key?(result, :put_url)

      encoded_filename = URI.encode(filename)

      expected_path =
        "uploads/tenants/#{tenant.tenant_id}/repositories/#{repository.id}/files/#{encoded_filename}"

      assert result[:get_url] =~ expected_path
      assert result[:put_url] =~ expected_path
    end

    test "read_presigned_url returns get presigned url only", %{tenant: tenant} do
      filename = "My File 1"

      repository = Edgehog.FilesFixtures.repository_fixture(tenant: tenant)

      result =
        File
        |> Ash.ActionInput.for_action(:read_presigned_url, %{
          filename: filename,
          repository_id: repository.id
        })
        |> Ash.run_action!(tenant: tenant)

      assert is_map(result)
      assert Map.has_key?(result, :get_url)

      encoded_filename = URI.encode(filename)

      expected_path =
        "uploads/tenants/#{tenant.tenant_id}/repositories/#{repository.id}/files/#{encoded_filename}"

      assert result[:get_url] =~ expected_path
    end

    test "presigned URL files can be uploaded and deleted" do
      tenant = Edgehog.TenantsFixtures.tenant_fixture()
      filename = "upload-test.bin"
      contents = "integration test contents"

      repository = Edgehog.FilesFixtures.repository_fixture(tenant: tenant)

      %{put_url: put_url, get_url: get_url} =
        File
        |> Ash.ActionInput.for_action(:create_presigned_url, %{
          filename: filename,
          repository_id: repository.id
        })
        |> Ash.run_action!(tenant: tenant)

      # Azure requires x-ms-blob-type; S3 ignores unknown headers on presigned PUTs
      assert {:ok, %{status_code: upload_status}} =
               HTTPoison.request(%HTTPoison.Request{
                 method: :put,
                 url: put_url,
                 body: contents,
                 headers: [
                   {"x-ms-blob-type", "BlockBlob"},
                   {"content-length", "#{byte_size(contents)}"}
                 ]
               })

      assert upload_status in [200, 201]

      assert {:ok, %{status_code: 200, body: ^contents}} =
               HTTPoison.request(%HTTPoison.Request{method: :get, url: get_url})

      file =
        Edgehog.FilesFixtures.file_fixture(
          repository_id: repository.id,
          tenant: tenant,
          name: filename
        )

      file |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy!()

      assert {:ok, %{status_code: 404}} =
               HTTPoison.request(%HTTPoison.Request{method: :get, url: get_url})
    end
  end

  describe "FileDownloadRequest presigned URL" do
    test "create_presigned_url returns presigned URLs containing the correct file path", %{
      tenant: tenant
    } do
      tenant_id = tenant.tenant_id
      file_download_request_id = "36075cab-9c99-4659-ab47-f5cb993e18e3"
      filename = "My File 1"

      result =
        FileDownloadRequest
        |> Ash.ActionInput.for_action(:create_presigned_url, %{
          filename: filename,
          file_download_request_id: file_download_request_id
        })
        |> Ash.run_action!(tenant: tenant)

      assert is_map(result)
      assert Map.has_key?(result, :get_url)
      assert Map.has_key?(result, :put_url)

      encoded_filename = URI.encode(filename)

      expected_path =
        "uploads/tenants/#{tenant_id}/ephemeral_file_download_requests/#{file_download_request_id}/files/#{encoded_filename}"

      assert result[:get_url] =~ expected_path
      assert result[:put_url] =~ expected_path
    end

    test "read_presigned_url returns get presigned url only", %{tenant: tenant} do
      tenant_id = tenant.tenant_id
      file_download_request_id = "36075cab-9c99-4659-ab47-f5cb993e18e3"
      filename = "My File 1"

      result =
        FileDownloadRequest
        |> Ash.ActionInput.for_action(:read_presigned_url, %{
          filename: filename,
          file_download_request_id: file_download_request_id
        })
        |> Ash.run_action!(tenant: tenant)

      assert is_map(result)
      assert Map.has_key?(result, :get_url)

      encoded_filename = URI.encode(filename)

      expected_path =
        "uploads/tenants/#{tenant_id}/ephemeral_file_download_requests/#{file_download_request_id}/files/#{encoded_filename}"

      assert result[:get_url] =~ expected_path
    end

    test "files can be uploaded" do
      tenant = Edgehog.TenantsFixtures.tenant_fixture()
      file_download_request_id = "36075cab-9c99-4659-ab47-f5cb993e18e3"
      filename = "upload-test.bin"
      contents = "integration test contents"

      %{put_url: put_url, get_url: get_url} =
        FileDownloadRequest
        |> Ash.ActionInput.for_action(:create_presigned_url, %{
          filename: filename,
          file_download_request_id: file_download_request_id
        })
        |> Ash.run_action!(tenant: tenant)

      # Azure requires x-ms-blob-type; S3 ignores unknown headers on presigned PUTs
      assert {:ok, %{status_code: upload_status}} =
               HTTPoison.request(%HTTPoison.Request{
                 method: :put,
                 url: put_url,
                 body: contents,
                 headers: [
                   {"x-ms-blob-type", "BlockBlob"},
                   {"content-length", "#{byte_size(contents)}"}
                 ]
               })

      assert upload_status in [200, 201]

      assert {:ok, %{status_code: 200, body: ^contents}} =
               HTTPoison.request(%HTTPoison.Request{method: :get, url: get_url})
    end
  end

  def temporary_file_fixture(opts \\ []) do
    file_name = Keyword.get(opts, :file_name, "example.bin")
    contents = Keyword.get(opts, :contents, "example")
    content_type = Keyword.get(opts, :content_type)

    temp_file = Plug.Upload.random_file!(file_name)
    Elixir.File.write!(temp_file, contents)

    %Plug.Upload{path: temp_file, filename: file_name, content_type: content_type}
  end
end
