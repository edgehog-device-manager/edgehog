import gleam/dynamic/decode.{type Decoder}
import gleam/option.{type Option}

pub type ImageCredentials {
  ImageCredentials(
    username: String,
    password: Option(String),
    label: String,
    id: String,
  )
}

pub fn decoder() -> Decoder(ImageCredentials) {
  use username <- decode.field("username", decode.string)
  use label <- decode.field("label", decode.string)
  use id <- decode.field("id", decode.string)
  echo decode.success(ImageCredentials(
    username: username,
    label: label,
    id: id,
    password: option.None,
  ))
}
