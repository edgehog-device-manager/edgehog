#
# This file is part of Edgehog.
#
# Copyright 2021-2023 SECO Mind Srl
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

alias Edgehog.{
  Astarte,
  BaseImages,
  Devices,
  Tenants
}

require Logger

default_var =
  if File.exists?("../.env") do
    defaults = Envar.read("../.env")

    fn var ->
      # paths in the .env are relative to ../
      Map.fetch!(defaults, var)
      |> String.replace_prefix("./", "../")
    end
  else
    fn _var -> nil end
  end

# gives priority to system env vars
read_env_var = fn var ->
  default = default_var.(var)
  System.get_env(var, default)
end

# original_file_name_var is used in docker to keep a reference to the original file.
read_file_from_env_var! = fn file_var, original_file_name_var ->
  file_name = read_env_var.(file_var)
  original_file_name = System.get_env(original_file_name_var, file_name)

  File.read(file_name)
  |> case do
    {:ok, content} ->
      content

    {:error, reason} ->
      raise ~s[#{file_var} (set to "#{original_file_name}"): #{:file.format_error(reason)}]
  end
end

{:ok, cluster} =
  Astarte.create_cluster(%{
    name: "Test Cluster",
    base_api_url: read_env_var.("SEEDS_ASTARTE_BASE_API_URL")
  })

default_key =
  :code.priv_dir(:edgehog)
  |> to_string()
  |> Path.join("repo/seeds/keys/tenant_private.pem")
  |> File.read!()

private_key =
  read_file_from_env_var!.("SEEDS_TENANT_PRIVATE_KEY_FILE", "SEEDS_TENANT_ORIGINAL_FILE")

if private_key == default_key do
  """
  Using default tenant private key. \
  Please be sure to avoid using this for production.
  """
  |> String.trim_trailing("\n")
  |> Logger.warning()
end

public_key =
  X509.PrivateKey.from_pem!(private_key)
  |> X509.PublicKey.derive()
  |> X509.PublicKey.to_pem()

{:ok, tenant} =
  Tenants.create_tenant(%{name: "ACME Inc", slug: "acme-inc", public_key: public_key})

_ = Edgehog.Repo.put_tenant_id(tenant.tenant_id)

realm_pk = read_file_from_env_var!.("SEEDS_REALM_PRIVATE_KEY_FILE", "SEEDS_REALM_ORIGINAL_FILE")

realm_pk =
  case X509.PrivateKey.from_pem(realm_pk) do
    {:ok, pk_binary} ->
      # Like returning pk but removes all text outside BEGIN KEY and END KEY sections.
      X509.PrivateKey.to_pem(pk_binary)

    {:error, _} ->
      """
      The realm's private key is not a valid RSA/RC private key. \
      This instance will not be able to connect to Astarte.
      """
      |> String.trim_trailing("\n")
      |> Logger.warning()

      realm_pk
  end

{:ok, realm} =
  Astarte.create_realm(cluster, %{
    name: read_env_var.("SEEDS_REALM"),
    private_key: realm_pk
  })

{:ok, hardware_type} =
  Devices.create_hardware_type(%{
    handle: "some-hardware-type",
    name: "Some hardware type",
    part_numbers: ["HT-1234"]
  })

{:ok, system_model} =
  Devices.create_system_model(hardware_type, %{
    handle: "some-system-model",
    name: "Some system model",
    part_numbers: ["AM-1234"]
  })

{:ok, _device} =
  Astarte.create_device(realm, %{
    name: "Thingie",
    device_id: "DqL4H107S42WBEHmDrvPLQ",
    part_number: "AM-1234"
  })

{:ok, _base_image_collection} =
  BaseImages.create_base_image_collection(system_model, %{
    handle: "ultra-firmware",
    name: "Ultra Firmware"
  })

:ok
