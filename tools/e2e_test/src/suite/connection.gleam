import gleam/http
import gleamql
import suite/env

pub fn new() -> gleamql.Request(t) {
  gleamql.new()
  |> gleamql.set_host(env.api_endpoint())
  |> gleamql.set_path(env.graphql_path())
  |> gleamql.set_header("Authorization", "Bearer " <> env.admin_jwt())
  |> gleamql.set_default_content_type_header()
  |> gleamql.set_scheme(http.Http)
}
