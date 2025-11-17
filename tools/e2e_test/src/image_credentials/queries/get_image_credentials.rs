use get_image_credentials::{ResponseData, Variables};
use graphql_client::{GraphQLQuery, Response};
use reqwest;
use std::fmt::Debug;

use crate::suite::client::EdgehogClient;

// The paths are relative to the directory where your `Cargo.toml` is located.
// Both json and the GraphQL schema language are supported as sources for the schema
#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "graphql/schema.graphql",
    query_path = "graphql/queries/image_credentials.graphql",
    response_derives = "Debug"
)]
pub struct GetImageCredentials;

impl GetImageCredentials {
    pub async fn get_image_credentials(
        client: &EdgehogClient,
        id: String,
    ) -> eyre::Result<Response<ResponseData>> {
        // this is the important line
        let variables = Variables { id };
        let request_body = GetImageCredentials::build_query(variables);
        client.send(&request_body).await
    }
}
