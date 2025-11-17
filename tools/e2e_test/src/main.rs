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

use clap::Parser;
use suite::client::EdgehogClient;
use suite::config::Config;

#[tokio::main]
async fn main() -> eyre::Result<()> {
    let config = Config::parse();
    let client = EdgehogClient::create(&config)?;
    image_credentials::run_test(client).await
}
