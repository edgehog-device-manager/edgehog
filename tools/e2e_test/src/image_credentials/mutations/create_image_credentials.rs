use create_image_credentials::{CreateImageCredentialsInput, ResponseData, Variables};
use graphql_client::{GraphQLQuery, Response};
use std::fmt::Debug;

use crate::suite::client::EdgehogClient;

// The paths are relative to the directory where your `Cargo.toml` is located.
// Both json and the GraphQL schema language are supported as sources for the schema
#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "graphql/schema.graphql",
    query_path = "graphql/mutations/create_image_credentials.graphql",
    response_derives = "Debug"
)]
pub struct CreateImageCredentials;

impl CreateImageCredentials {
    pub async fn create_image_credentials(
        client: &EdgehogClient,
        username: String,
        password: String,
        label: String,
    ) -> eyre::Result<Response<ResponseData>> {
        // this is the important line
        let input = CreateImageCredentialsInput {
            username,
            label,
            password,
        };
        let variables = Variables { input };
        let request_body = CreateImageCredentials::build_query(variables);
        client.send(&request_body) .await
    }
}
