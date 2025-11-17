import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleamql.{type GraphQLError}

pub type ErrorSet =
  Dict(String, List(GraphQLError))

pub fn print(errors: ErrorSet) {
  dict.each(errors, print_errors)
}

pub fn print_errors(set_name: String, errors: List(GraphQLError)) {
  io.println(" ### Errors in " <> set_name <> " ### ")
  list.each(errors, print_error)
}

pub fn print_error(error: GraphQLError) {
  case error {
    gleamql.ErrorMessage(message) ->
      io.println_error("Error while resolving a call: " <> message)
    gleamql.UnexpectedStatus(status) ->
      io.println_error("Unexpected status: " <> int.to_string(status))
    gleamql.UnknownError -> io.println_error("Unknown error!")
    gleamql.UnrecognisedResponse(response) ->
      io.println_error("Unexpected response: " <> response)
  }
}
