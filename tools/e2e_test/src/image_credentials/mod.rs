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

use crate::suite::client;

pub mod mutations;
pub mod queries;

pub async fn run_test(client: client::EdgehogClient) -> eyre::Result<()> {
    let image_credentials_result = CreateImageCredentials::create_image_credentials(
        &client,
        "user2".to_string(),
        "password".to_string(),
        "label2".to_string(),
    )
    .await?;

    dbg!(image_credentials_result);

    let id = String::from("1");

    match GetImageCredentials::get_image_credentials(&client, id).await {
        Ok(response_data) => {
            dbg!(response_data);
            ()
        }
        Err(error) => {
            let _ = dbg!(error);
            ()
        }
    };

    Ok(())
}
