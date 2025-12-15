import gleam/dynamic/decode.{type Decoder}
import suite/types/request_data.{type Data}
import suite/types/request_error.{type Error, decode_error}

pub type Request(t) {
  Request(data: Data(t), errors: List(Error))
}

pub fn decode_request(subfield_decoder: Decoder(t)) -> Decoder(Request(t)) {
  let data_decoder = request_data.decode_data(subfield_decoder)

  use data <- decode.field("data", data_decoder)
  use errors <- decode.field("errors", decode.list(decode_error()))
  decode.success(Request(data: data, errors: errors))
}
