import gleam/dict
import gleam/dynamic/decode.{type Decoder}
import gleam/function
import gleam/hackney
import gleam/json
import gleam/list
import gleamql
import suite/connection
import suite/logging
import types/image_credentials.{type ImageCredentials}

const create_image_credentials = "mutation CreateImageCredentials($input: CreateImageCredentialsInput!){
  createImageCredentials(input: $input) {
    result {
      username
      label
      id
    }
  }
}"

pub fn create_image_credentials_decoder() -> Decoder(ImageCredentials) {
  let root = ["data", "createImageCredentials", "result"]
  use result <- decode.subfield(root, image_credentials.decoder())
  echo result
  decode.success(result)
}

pub fn create_credentials(
  errors: List(gleamql.GraphQLError),
) -> List(gleamql.GraphQLError) {
  let input =
    dict.from_list([
      #("label", "Test Credentials 2"),
      #("username", "user3"),
      #("password", "password"),
    ])

  let res =
    connection.new()
    |> gleamql.set_query(create_image_credentials)
    |> gleamql.set_variable(
      "input",
      json.dict(input, function.identity, json.string),
    )
    |> gleamql.set_decoder(create_image_credentials_decoder())
    |> gleamql.send(hackney.send)
    |> echo

  case res {
    Error(error) -> {
      logging.fail("create_credentials")
      list.append(errors, [error])
    }
    Ok(image_credntials_raw) -> {
      echo image_credntials_raw

      logging.pass("create_credentials")
      errors
    }
  }
}
