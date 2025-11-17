import gleamql

pub type Context(t) {
  Context(connection: gleamql.Request(t), errors: List(gleamql.GraphQLError))
}
