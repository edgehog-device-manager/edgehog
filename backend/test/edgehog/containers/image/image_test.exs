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

defmodule Edgehog.Containers.ImageTest do
  use Edgehog.DataCase, async: true

  import Edgehog.ContainersFixtures
  import Edgehog.TenantsFixtures

  alias Edgehog.Containers.Image

  setup do
    %{tenant: tenant_fixture()}
  end

  describe "reference calculation" do
    test "formats image name only", %{tenant: tenant} do
      image = image_fixture(tenant: tenant, image: "alpine")

      assert image.reference == "alpine"
    end

    test "formats image with tag", %{tenant: tenant} do
      image = image_fixture(tenant: tenant, image: "alpine", tag: "3.18")

      assert image.reference == "alpine:3.18"
    end

    test "formats image with digest", %{tenant: tenant} do
      digest = unique_image_digest()
      image = image_fixture(tenant: tenant, image: "alpine", digest: digest)

      assert image.reference == "alpine@#{digest}"
    end

    test "formats repository, image, and tag", %{tenant: tenant} do
      image =
        image_fixture(
          tenant: tenant,
          repository: "library/nested",
          image: "nginx",
          tag: "1.25-alpine"
        )

      assert image.reference == "library/nested/nginx:1.25-alpine"
    end

    test "formats registry_host, image, and tag without port or repository", %{tenant: tenant} do
      image =
        image_fixture(
          tenant: tenant,
          registry_host: "ghcr.io",
          image: "edgehog-device-runtime",
          tag: "latest"
        )

      assert image.reference == "ghcr.io/edgehog-device-runtime:latest"
    end

    test "formats full segments with tag", %{tenant: tenant} do
      image =
        image_fixture(
          tenant: tenant,
          registry_host: "registry.example.com",
          registry_port: 5000,
          repository: "seco/edgehog",
          image: "backend",
          tag: "v1.2.3"
        )

      assert image.reference == "registry.example.com:5000/seco/edgehog/backend:v1.2.3"
    end

    test "formats full segments with digest", %{tenant: tenant} do
      digest = unique_image_digest()

      image =
        image_fixture(
          tenant: tenant,
          registry_host: "registry.example.com",
          registry_port: 5000,
          repository: "seco/edgehog",
          image: "backend",
          digest: digest
        )

      assert image.reference == "registry.example.com:5000/seco/edgehog/backend@#{digest}"
    end

    test "automatically loads reference on read queries", %{tenant: tenant} do
      created = image_fixture(tenant: tenant, image: "postgres", tag: "16.6-alpine")

      fetched = Ash.get!(Image, created.id, tenant: tenant)
      assert fetched.reference == "postgres:16.6-alpine"
    end
  end

  describe "segment validations" do
    test "fails when image is missing", %{tenant: tenant} do
      assert {:error, %Ash.Error.Invalid{}} =
               Image
               |> Ash.Changeset.for_create(:create, %{tag: "latest"}, tenant: tenant)
               |> Ash.create()
    end

    test "fails when both tag and digest are provided", %{tenant: tenant} do
      params = %{
        image: "alpine",
        tag: "3.18",
        digest: unique_image_digest()
      }

      assert {:error, %Ash.Error.Invalid{} = error} =
               Image
               |> Ash.Changeset.for_create(:create, params, tenant: tenant)
               |> Ash.create()

      assert Enum.any?(error.errors, fn err ->
               err.message == "You can either set a tag or the image digest, not both."
             end)
    end

    test "validates tag format", %{tenant: tenant} do
      for invalid_tag <- ["-leading-dash", ".leading-dot", "bad:colon", "bad/slash", "bad space"] do
        assert {:error, %Ash.Error.Invalid{}} =
                 Image
                 |> Ash.Changeset.for_create(
                   :create,
                   %{image: unique_image_name(), tag: invalid_tag},
                   tenant: tenant
                 )
                 |> Ash.create()
      end
    end

    test "validates digest format", %{tenant: tenant} do
      for invalid_digest <- [
            "md5:0123456789abcdef0123456789abcdef",
            "sha256:tooshort",
            "sha256:zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
          ] do
        assert {:error, %Ash.Error.Invalid{}} =
                 Image
                 |> Ash.Changeset.for_create(
                   :create,
                   %{image: unique_image_name(), digest: invalid_digest},
                   tenant: tenant
                 )
                 |> Ash.create()
      end
    end

    test "fails when registry_port is set without registry_host", %{tenant: tenant} do
      params = %{
        registry_port: 5000,
        image: "alpine"
      }

      assert {:error, %Ash.Error.Invalid{} = error} =
               Image
               |> Ash.Changeset.for_create(:create, params, tenant: tenant)
               |> Ash.create()

      assert Enum.any?(error.errors, fn err ->
               err.field == :registry_host and
                 err.message == "must be present when registry_port is set"
             end)
    end

    test "validates registry_port bounds", %{tenant: tenant} do
      for invalid_port <- [0, -1, 65_536] do
        assert {:error, %Ash.Error.Invalid{}} =
                 Image
                 |> Ash.Changeset.for_create(
                   :create,
                   %{
                     registry_host: "registry.example.com",
                     registry_port: invalid_port,
                     image: unique_image_name()
                   },
                   tenant: tenant
                 )
                 |> Ash.create()
      end
    end

    test "prevents duplicate plain images with identical segments", %{tenant: tenant} do
      params = %{
        registry_host: "registry.example.com",
        registry_port: 5000,
        repository: "org/team",
        image: "app",
        tag: "1.0.0"
      }

      _existing = image_fixture([tenant: tenant] ++ Map.to_list(params))

      assert {:error, %Ash.Error.Invalid{}} =
               Image
               |> Ash.Changeset.for_create(:create, params, tenant: tenant)
               |> Ash.create()
    end
  end

  describe "container_fixture/1 image pass-down" do
    test "reuses an existing %Image{} struct passed to container_fixture", %{tenant: tenant} do
      credentials = image_credentials_fixture(tenant: tenant)

      image =
        image_fixture(
          tenant: tenant,
          registry_host: unique_image_registry_host(),
          registry_port: unique_image_registry_port(),
          repository: unique_image_repository(),
          image: unique_image_name(),
          tag: unique_image_tag(),
          image_credentials_id: credentials.id
        )

      container =
        [tenant: tenant, image: image]
        |> container_fixture()
        |> Ash.load!(:image)

      assert container.image_id == image.id
      assert container.image.reference == image.reference
    end

    test "reuses an existing image by id passed to container_fixture", %{tenant: tenant} do
      image =
        image_fixture(
          tenant: tenant,
          image: unique_image_name(),
          digest: unique_image_digest()
        )

      container =
        [tenant: tenant, image: image.id]
        |> container_fixture()
        |> Ash.load!(:image)

      assert container.image_id == image.id
      assert container.image.reference == image.reference
    end

    test "accepts a segment map passed to container_fixture", %{tenant: tenant} do
      image_map = %{
        registry_host: "ghcr.io",
        repository: "edgehog-device-runtime",
        image: "runtime",
        tag: "v0.9.0"
      }

      container =
        [tenant: tenant, image: image_map]
        |> container_fixture()
        |> Ash.load!(:image)

      assert container.image.reference == "ghcr.io/edgehog-device-runtime/runtime:v0.9.0"
    end
  end
end
