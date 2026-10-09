// This file is part of Edgehog.
//
// Copyright 2026 SECO Mind Srl
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

use create_application::{CreateApplicationInput, ResponseData, Variables};
use graphql_client::{GraphQLQuery, Response};
use std::fmt::Debug;

use crate::suite::client::EdgehogClient;

// The paths are relative to the directory where your `Cargo.toml` is located.
// Both json and the GraphQL schema language are supported as sources for the schema
#[derive(GraphQLQuery)]
#[graphql(
    schema_path = "graphql/schema.graphql",
    query_path = "graphql/mutations/create_application.graphql",
    response_derives = "Debug"
)]
pub struct CreateApplication;

impl CreateApplication {
    pub async fn create_application(
        client: &EdgehogClient,
        name: &String,
        description: Option<String>,
    ) -> eyre::Result<Response<ResponseData>> {
        let input = CreateApplicationInput {
            name: String::from(name),
            description,
            initial_release: None,
            system_model_id: None,
        };
        let variables = Variables { input };
        let request_body = CreateApplication::build_query(variables);
        client.send(&request_body).await
    }
}
