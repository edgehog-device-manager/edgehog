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

mod image_credentials;
mod suite;

#[tokio::main]
async fn main() -> eyre::Result<()> {
    Ok(())
}

#[cfg(test)]
mod test {
    use super::*;

    use suite::client::EdgehogClient;
    use suite::config::Config;

    fn test_config() -> Config {
        Config {
            hostname: "api.edgehog.localhost".to_string(),
            scheme: "http".to_string(),
            bearer: "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJlX3RnYSI6IioiLCJpYXQiOjE3Mzg5NDgzODh9.TTiXYs1LucAnS_6RGp7pWg-S30NSt7eqL7lU8BzT5BWlHctk7NYZwC6lftA6WeEb1HKEJfPoUqWeOeZ6oYA0AA".to_string(),
            tenant: "test".to_string()
        }
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 1)]
    async fn image_credentials() -> eyre::Result<()> {
        let config = test_config();

        let client = EdgehogClient::create(&config)?;
        image_credentials::test_image_credentials(client).await
    }
}
