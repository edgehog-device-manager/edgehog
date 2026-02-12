// This file is part of Edgehog.
//
// Copyright 2025 SECO Mind Srl
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

use mutations::create_image_credentials::CreateImageCredentials;
use queries::get_image_credentials::GetImageCredentials;
use rand::distr::{Alphabetic, SampleString};

use crate::suite::client;

pub mod mutations;
pub mod queries;

pub async fn test_image_credentials(client: client::EdgehogClient) -> eyre::Result<()> {
    let username = Alphabetic.sample_string(&mut rand::rng(), 5);
    let label = Alphabetic.sample_string(&mut rand::rng(), 5);
    let password = Alphabetic.sample_string(&mut rand::rng(), 10);

    let image_credentials_result =
        CreateImageCredentials::create_image_credentials(&client, &username, &password, &label)
            .await?;

    println!("Image credentials creation result:");

    println!(
        "Image credentials creation result: {:?}",
        image_credentials_result
    );

    assert_eq!(image_credentials_result.errors, None);

    let created_credentials = image_credentials_result
        .data
        .expect("Error wile unwrapping image credentials creation result")
        .create_image_credentials
        .expect("Error while unwrapping image credentials creation result")
        .result
        .expect("Error while unwrapping image credentials creation result");

    assert_eq!(username, created_credentials.username);
    assert_eq!(label, created_credentials.label);

    let id = created_credentials.id.clone();

    let image_credentials = GetImageCredentials::get_image_credentials(&client, &id)
        .await?
        .data
        .expect(format!("Error while retrieving image credentials with id {}", &id).as_str())
        .image_credentials
        .expect(format!("Error while retrieving image credentials with id {}", &id).as_str());

    assert_eq!(image_credentials.username, username);
    assert_eq!(image_credentials.label, label);

    Ok(())
}
