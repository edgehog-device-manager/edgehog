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
