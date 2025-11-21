use clap::Parser;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
pub struct Config {
    /// Edgehog api host name, e.g. api.edgehog.localhost
    #[arg(long, default_value="api.edgehog.localhost", env="EDGEHOG_TEST_HOSTNAME")]
    pub hostname: String,

    /// Scheme to run graphql queries, e.g. http
    #[arg(long, default_value="http", env="EDGEHOG_TEST_SCHEME")]
    pub scheme: String,

    /// tenant jwt to authorize requests
    #[arg(long, env="EDGEHOG_TEST_BEARER")]
    pub bearer: String,

    /// tenant slug
    #[arg(long, default_value="test", env="EDGEHOG_TEST_TENANT")]
    pub tenant: String,
}
