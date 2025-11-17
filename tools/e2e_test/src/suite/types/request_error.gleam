import gleam/dict
import gleam/dynamic/decode.{type Decoder}

pub type Error {
  Error(
    code: String,
    message: String,
    path: List(String),
    fields: List(String),
    vars: dict.Dict(String, String),
    locations: List(dict.Dict(String, Int)),
  )
}

pub fn decode_error() -> Decoder(Error) {
  use code <- decode.field("code", decode.string)
  use message <- decode.field("message", decode.string)
  use path <- decode.field("path", decode.list(decode.string))
  use fields <- decode.field("fields", decode.list(decode.string))
  use vars <- decode.field("vars", decode.dict(decode.string, decode.string))
  use locations <- decode.field(
    "locations",
    decode.list(decode.dict(decode.string, decode.int)),
  )
  decode.success(Error(
    code: code,
    message: message,
    path: path,
    fields: fields,
    vars: vars,
    locations: locations,
  ))
}
