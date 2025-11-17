import gleam/dict
import suite/errors
import tests/image_credentials

pub fn main() -> Result(Nil, errors.ErrorSet) {
  dict.new()
  |> image_credentials.run_test()
  |> errors.print()
  |> Ok
}
