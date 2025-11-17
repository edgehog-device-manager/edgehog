import gleam/dict
import gleamql
import suite/errors.{type ErrorSet}
import tests/image_credentials/create_credentials

pub fn run_test(init_errors: ErrorSet) -> ErrorSet {
  let errors: List(gleamql.GraphQLError) =
    []
    |> create_credentials.create_credentials()

  dict.insert(init_errors, "ImageCredentials", errors)
}
