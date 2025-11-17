import envoy

pub fn api_endpoint() -> String {
  let endpoint = envoy.get("TEST_EDGEHOG_API_ENDPOINT")

  case endpoint {
    Ok(endpoint) -> endpoint
    Error(_) -> "api.edgehog.localhost"
  }
}

pub fn graphql_path() -> String {
  let path = envoy.get("TEST_EDGEHOG_TENANT")

  case path {
    Ok(path) -> path
    Error(_) -> "/tenants/test/api"
  }
}

pub fn admin_jwt() -> String {
  let jwt = envoy.get("TEST_EDGEHOG_JWT")

  case jwt {
    Ok(jwt) -> jwt
    // defaults to the jwt stored in "backend/priv/repo/seeds/keys/tenant_jwt.txt"
    Error(_) ->
      "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJlX3RnYSI6IioiLCJpYXQiOjE3Mzg5NDgzODh9.TTiXYs1LucAnS_6RGp7pWg-S30NSt7eqL7lU8BzT5BWlHctk7NYZwC6lftA6WeEb1HKEJfPoUqWeOeZ6oYA0AA"
  }
}
