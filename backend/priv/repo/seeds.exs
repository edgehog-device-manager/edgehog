#
# This file is part of Edgehog.
#
# Copyright 2021 SECO Mind Srl
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

alias Edgehog.{
  Devices,
  Astarte,
  Tenants
}

{:ok, cluster} =
  Astarte.create_cluster(%{
    name: "Test Cluster",
    base_api_url: "https://api.astarte.example.com"
  })

private_key = """
-----BEGIN EC PRIVATE KEY-----
MHcCAQEEICx5W2odFd5CyMTv5VlLW96fgvWtcJ3bIJVVc3GWhMHBoAoGCCqGSM49
AwEHoUQDQgAEhV0KI4hByk0uDkCg4yZImMTiAtz2azmpbh0sLAKOESdlRYOFw90U
p4F9fRRV5Li6Pn5XZiMCZhVkS/PoUbIKpA==
-----END EC PRIVATE KEY-----
"""

public_key =
  X509.PrivateKey.from_pem!(private_key)
  |> X509.PublicKey.derive()
  |> X509.PublicKey.to_pem()

{:ok, tenant} =
  Tenants.create_tenant(%{name: "ACME Inc", slug: "acme-inc", public_key: public_key})

_ = Edgehog.Repo.put_tenant_id(tenant.tenant_id)

{:ok, realm} = Astarte.create_realm(cluster, %{name: "test", private_key: "notaprivatekey"})

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
