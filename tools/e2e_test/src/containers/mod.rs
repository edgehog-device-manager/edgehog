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

use mutations::create_application::CreateApplication;
use queries::get_application::GetApplication;
use rand::distr::{Alphabetic, SampleString};

use crate::suite::client;

pub mod mutations;
pub mod queries;

pub async fn test_application(client: client::EdgehogClient) -> eyre::Result<()> {
    let name = Alphabetic.sample_string(&mut rand::rng(), 10);
    let description = Some(Alphabetic.sample_string(&mut rand::rng(), 20));

    let application_result =
        CreateApplication::create_application(&client, &name, description.clone()).await?;

    assert_eq!(application_result.errors, None);

    let created_application = application_result
        .data
        .expect("Error while unwrapping application creation result")
        .create_application
        .expect("Error while unwrapping application creation result")
        .result
        .expect("Error while unwrapping application creation result");

    assert_eq!(description, created_application.description);

    let id = created_application.id.clone();

    let application = GetApplication::get_application(&client, &id)
        .await?
        .data
        .expect(format!("Error while retrieving application with id {}", &id).as_str())
        .application
        .expect(format!("Error while retrieving application with id {}", &id).as_str());

    assert_eq!(application.name, name);
    assert_eq!(application.description, description);

    Ok(())
}
