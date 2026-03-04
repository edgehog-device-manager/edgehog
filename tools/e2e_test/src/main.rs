// This file is part of Edgehog.
//
// Copyright 2025 - 2026 SECO Mind Srl
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

mod containers;
mod image_credentials;
mod suite;

#[tokio::main]
async fn main() -> eyre::Result<()> {
    Ok(())
}

#[cfg(test)]
mod test {
    use super::*;

    use std::env;
    use suite::client::EdgehogClient;
    use suite::config::Config;

    fn test_config() -> Config {
        Config {
            hostname: env::var("EDGEHOG_TEST_HOSTNAME")
                .unwrap_or_else(|_| "api.edgehog.localhost".to_string()),
            scheme: env::var("EDGEHOG_TEST_SCHEME").unwrap_or_else(|_| "http".to_string()),
            bearer: env::var("EDGEHOG_TEST_BEARER")
                .expect("Bearer token must be set in EDGEHOG_TEST_BEARER"),
            tenant: env::var("EDGEHOG_TEST_TENANT").unwrap_or_else(|_| "test".to_string()),
        }
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn image_credentials() -> eyre::Result<()> {
        let config = test_config();

        let client = EdgehogClient::create(&config)?;
        image_credentials::test_image_credentials(client).await
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn application() -> eyre::Result<()> {
        let config = test_config();

        println!("Test config: {:?}", config);

        let client = EdgehogClient::create(&config)?;
        containers::test_application(client).await
    }
}
