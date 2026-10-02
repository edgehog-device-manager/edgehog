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

defmodule Edgehog.Storage.S3Test do
  use ExUnit.Case, async: false

  alias Edgehog.Storage.S3

  setup do
    original_bucket = Application.get_env(:edgehog, :storage_bucket)
    original_host_config = Application.get_env(:edgehog, :s3_presign_host_config)
    original_access_key = Application.get_env(:ex_aws, :access_key_id)
    original_secret_key = Application.get_env(:ex_aws, :secret_access_key)
    original_region = Application.get_env(:ex_aws, :region)

    Application.put_env(:edgehog, :storage_bucket, "test-bucket")
    Application.put_env(:ex_aws, :access_key_id, "test_access_key")
    Application.put_env(:ex_aws, :secret_access_key, "test_secret_key")
    Application.put_env(:ex_aws, :region, "us-east-1")

    on_exit(fn ->
      if original_bucket,
        do: Application.put_env(:edgehog, :storage_bucket, original_bucket),
        else: Application.delete_env(:edgehog, :storage_bucket)

      if original_host_config,
        do: Application.put_env(:edgehog, :s3_presign_host_config, original_host_config),
        else: Application.delete_env(:edgehog, :s3_presign_host_config)

      if original_access_key,
        do: Application.put_env(:ex_aws, :access_key_id, original_access_key),
        else: Application.delete_env(:ex_aws, :access_key_id)

      if original_secret_key,
        do: Application.put_env(:ex_aws, :secret_access_key, original_secret_key),
        else: Application.delete_env(:ex_aws, :secret_access_key)

      if original_region,
        do: Application.put_env(:ex_aws, :region, original_region),
        else: Application.delete_env(:ex_aws, :region)
    end)

    :ok
  end

  describe "presigned URLs without public path prefix" do
    test "generates standard presigned URLs when public_path_prefix is not set" do
      Application.put_env(:edgehog, :s3_presign_host_config, %{
        scheme: "https://",
        host: "storage.example.com",
        port: 443
      })

      assert {:ok, %{get_url: get_url, put_url: put_url}} =
               S3.create_presigned_urls("uploads/file.bin")

      assert String.starts_with?(
               get_url,
               "https://storage.example.com/test-bucket/uploads/file.bin?"
             )

      assert String.starts_with?(
               put_url,
               "https://storage.example.com/test-bucket/uploads/file.bin?"
             )

      assert String.contains?(get_url, "X-Amz-Signature=")
      assert String.contains?(put_url, "X-Amz-Signature=")
    end

    test "generates standard presigned URLs when public_path_prefix is nil or empty" do
      for prefix <- [nil, "", "/"] do
        Application.put_env(:edgehog, :s3_presign_host_config, %{
          scheme: "https://",
          host: "storage.example.com",
          port: 443,
          public_path_prefix: prefix
        })

        assert {:ok, %{get_url: get_url}} = S3.read_presigned_url("uploads/file.bin")

        assert String.starts_with?(
                 get_url,
                 "https://storage.example.com/test-bucket/uploads/file.bin?"
               )
      end
    end
  end

  describe "presigned URLs with public path prefix" do
    test "prepends prefix with leading slash" do
      Application.put_env(:edgehog, :s3_presign_host_config, %{
        scheme: "https://",
        host: "192.168.1.100",
        port: 443,
        public_path_prefix: "/minio"
      })

      assert {:ok, %{get_url: get_url, put_url: put_url}} =
               S3.create_presigned_urls("uploads/file.bin")

      assert String.starts_with?(
               get_url,
               "https://192.168.1.100/minio/test-bucket/uploads/file.bin?"
             )

      assert String.starts_with?(
               put_url,
               "https://192.168.1.100/minio/test-bucket/uploads/file.bin?"
             )

      # Ensure SigV4 query params are preserved
      uri = URI.parse(put_url)
      query_params = URI.decode_query(uri.query)
      assert Map.has_key?(query_params, "X-Amz-Signature")
      assert Map.has_key?(query_params, "X-Amz-Algorithm")
      assert Map.has_key?(query_params, "X-Amz-Credential")
    end

    test "normalizes prefix without leading slash or with trailing slash" do
      for prefix <- ["minio", "/minio/", "minio/"] do
        Application.put_env(:edgehog, :s3_presign_host_config, %{
          scheme: "https://",
          host: "services.example.com",
          port: 443,
          public_path_prefix: prefix
        })

        assert {:ok, %{get_url: get_url}} = S3.read_presigned_url("uploads/file.bin")

        assert String.starts_with?(
                 get_url,
                 "https://services.example.com/minio/test-bucket/uploads/file.bin?"
               )
      end
    end

    test "supports multi-segment path prefixes" do
      Application.put_env(:edgehog, :s3_presign_host_config, %{
        scheme: "https://",
        host: "services.example.com",
        port: 8443,
        public_path_prefix: "/storage/minio"
      })

      assert {:ok, %{get_url: get_url}} = S3.read_presigned_url("uploads/file.bin")

      assert String.starts_with?(
               get_url,
               "https://services.example.com:8443/storage/minio/test-bucket/uploads/file.bin?"
             )
    end

    test "normalizes prefixes with whitespace or multiple surrounding slashes" do
      Application.put_env(:edgehog, :s3_presign_host_config, %{
        scheme: "https://",
        host: "services.example.com",
        port: 443,
        public_path_prefix: "  ///minio///  "
      })

      assert {:ok, %{get_url: get_url}} = S3.read_presigned_url("uploads/file.bin")

      assert String.starts_with?(
               get_url,
               "https://services.example.com/minio/test-bucket/uploads/file.bin?"
             )
    end

    test "does not duplicate prefix when bucket or path already starts with prefix" do
      Application.put_env(:edgehog, :storage_bucket, "minio-bucket")

      Application.put_env(:edgehog, :s3_presign_host_config, %{
        scheme: "https://",
        host: "services.example.com",
        port: 443,
        public_path_prefix: "/minio"
      })

      assert {:ok, %{get_url: get_url}} = S3.read_presigned_url("uploads/file.bin")

      # Should be /minio/minio-bucket/... not /minio-bucket/...
      assert String.starts_with?(
               get_url,
               "https://services.example.com/minio/minio-bucket/uploads/file.bin?"
             )
    end
  end
end
