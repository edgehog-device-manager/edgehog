import gleam/dynamic/decode.{type Decoder}

pub type Data(t) {
  Data(data: t)
}

pub fn decode_data(subfield_decoder: Decoder(t)) -> Decoder(Data(t)) {
  use data <- decode.field("data", subfield_decoder)
  decode.success(Data(data: data))
}
