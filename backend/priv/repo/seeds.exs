alias Edgehog.{
  Astarte,
  Tenants
}

{:ok, cluster} =
  Astarte.create_cluster(%{
    name: "Test Cluster",
    base_api_url: "https://api.astarte.example.com"
  })

{:ok, tenant} = Tenants.create_tenant(%{name: "ACME Inc"})

_ = Edgehog.Repo.put_tenant_id(tenant.tenant_id)

{:ok, realm} = Astarte.create_realm(cluster, %{name: "test", private_key: "notaprivatekey"})

{:ok, _device} =
  Astarte.create_device(realm, %{name: "Thingie", device_id: "DqL4H107S42WBEHmDrvPLQ"})
