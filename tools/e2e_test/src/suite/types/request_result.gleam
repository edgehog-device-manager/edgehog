import gleam/dynamic/decode.{type Decoder}

pub type Result(t) {
  Result(result: t)
}

pub fn decode_result(subfield_decoder: Decoder(t)) -> Decoder(Result(t)) {
  use result <- decode.field("result", subfield_decoder)
  decode.success(Result(result: result))
}
