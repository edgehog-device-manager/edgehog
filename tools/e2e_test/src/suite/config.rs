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

use clap::Parser;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
pub struct Config {
    /// Edgehog api host name, e.g. api.edgehog.localhost
    #[arg(
        long,
        default_value = "api.edgehog.localhost",
        env = "EDGEHOG_TEST_HOSTNAME"
    )]
    pub hostname: String,

    /// Scheme to run graphql queries, e.g. http
    #[arg(long, default_value = "http", env = "EDGEHOG_TEST_SCHEME")]
    pub scheme: String,

    /// tenant jwt to authorize requests
    #[arg(long, env = "EDGEHOG_TEST_BEARER")]
    pub bearer: String,

    /// tenant slug
    #[arg(long, default_value = "test", env = "EDGEHOG_TEST_TENANT")]
    pub tenant: String,
}
